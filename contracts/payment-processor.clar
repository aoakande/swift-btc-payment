;; SwiftBTC Payment Processor Contract
;; Core contract for sBTC-native payment processing with sub-10s settlement

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-PAYMENT (err u101))
(define-constant ERR-PAYMENT-NOT-FOUND (err u102))
(define-constant ERR-PAYMENT-ALREADY-PROCESSED (err u103))
(define-constant ERR-INSUFFICIENT-BALANCE (err u104))
(define-constant ERR-PAYMENT-EXPIRED (err u106))
(define-constant ERR-INVALID-AMOUNT (err u107))

;; Payment status constants
(define-constant STATUS-PENDING u0)
(define-constant STATUS-CONFIRMED u1)
(define-constant STATUS-SETTLED u2)

;; Data Variables
(define-data-var payment-counter uint u0)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points

;; Data Maps
(define-map payments
  { payment-id: uint }
  {
    merchant: principal,
    payer: (optional principal),
    amount: uint,
    sbtc-amount: uint,
    status: uint,
    created-at: uint,
    expires-at: uint,
    settled-at: (optional uint),
    payment-reference: (string-ascii 64)
  }
)

(define-map merchant-balances
  { merchant: principal }
  { available: uint, pending: uint }
)

(define-map payment-settlements
  { payment-id: uint }
  {
    settlement-amount: uint,
    platform-fee: uint,
    merchant-amount: uint,
    settled-by: principal
  }
)

;; Read-only functions
(define-read-only (get-payment (payment-id uint))
  (map-get? payments { payment-id: payment-id })
)

(define-read-only (get-merchant-balance (merchant principal))
  (default-to { available: u0, pending: u0 }
    (map-get? merchant-balances { merchant: merchant })
  )
)

(define-read-only (get-payment-settlement (payment-id uint))
  (map-get? payment-settlements { payment-id: payment-id })
)

(define-read-only (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000)
)

(define-read-only (get-current-payment-counter)
  (var-get payment-counter)
)

(define-read-only (is-payment-expired (payment-id uint))
  (match (get-payment payment-id)
    payment (> stacks-block-height (get expires-at payment))
    false
  )
)

;; Private functions
(define-private (increment-payment-counter)
  (let ((current (var-get payment-counter)))
    (var-set payment-counter (+ current u1))
    (+ current u1)
  )
)

(define-private (update-merchant-balance (merchant principal) (available-delta int) (pending-delta int))
  (let ((current-balance (get-merchant-balance merchant)))
    (map-set merchant-balances
      { merchant: merchant }
      {
        available: (+ (get available current-balance) (if (< available-delta 0) u0 (to-uint available-delta))),
        pending: (+ (get pending current-balance) (if (< pending-delta 0) u0 (to-uint pending-delta)))
      }
    )
  )
)

;; Public functions

;; Create a new payment request
(define-public (create-payment 
  (merchant principal)
  (amount uint)
  (sbtc-amount uint)
  (expires-in-blocks uint)
  (payment-reference (string-ascii 64))
)
  (let (
    (payment-id (increment-payment-counter))
    (expires-at (+ stacks-block-height expires-in-blocks))
  )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> sbtc-amount u0) ERR-INVALID-AMOUNT)
    (asserts! (> expires-in-blocks u0) ERR-INVALID-PAYMENT)
    
    (map-set payments
      { payment-id: payment-id }
      {
        merchant: merchant,
        payer: none,
        amount: amount,
        sbtc-amount: sbtc-amount,
        status: STATUS-PENDING,
        created-at: stacks-block-height,
        expires-at: expires-at,
        settled-at: none,
        payment-reference: payment-reference
      }
    )
    
    ;; Update merchant pending balance
    (update-merchant-balance merchant 0 (to-int sbtc-amount))
    
    (print {
      event: "payment-created",
      payment-id: payment-id,
      merchant: merchant,
      amount: amount,
      sbtc-amount: sbtc-amount
    })
    
    (ok payment-id)
  )
)

;; Process payment (called by payer)
(define-public (process-payment (payment-id uint))
  (let (
    (payment (unwrap! (get-payment payment-id) ERR-PAYMENT-NOT-FOUND))
    (payer tx-sender)
  )
    (asserts! (is-eq (get status payment) STATUS-PENDING) ERR-PAYMENT-ALREADY-PROCESSED)
    (asserts! (<= stacks-block-height (get expires-at payment)) ERR-PAYMENT-EXPIRED)
    
    ;; Update payment status
    (map-set payments
      { payment-id: payment-id }
      (merge payment {
        payer: (some payer),
        status: STATUS-CONFIRMED
      })
    )
    
    (print {
      event: "payment-processed",
      payment-id: payment-id,
      payer: payer,
      amount: (get sbtc-amount payment)
    })
    
    (ok true)
  )
)

;; Settle payment (transfer funds to merchant)
(define-public (settle-payment (payment-id uint))
  (let (
    (payment (unwrap! (get-payment payment-id) ERR-PAYMENT-NOT-FOUND))
    (platform-fee (calculate-platform-fee (get sbtc-amount payment)))
    (merchant-amount (- (get sbtc-amount payment) platform-fee))
  )
    (asserts! (is-eq (get status payment) STATUS-CONFIRMED) ERR-INVALID-PAYMENT)
    
    ;; Update payment status
    (map-set payments
      { payment-id: payment-id }
      (merge payment {
        status: STATUS-SETTLED,
        settled-at: (some stacks-block-height)
      })
    )
    
    ;; Record settlement details
    (map-set payment-settlements
      { payment-id: payment-id }
      {
        settlement-amount: (get sbtc-amount payment),
        platform-fee: platform-fee,
        merchant-amount: merchant-amount,
        settled-by: tx-sender
      }
    )
    
    ;; Update merchant balances
    (update-merchant-balance 
      (get merchant payment) 
      (to-int merchant-amount) 
      (- 0 (to-int (get sbtc-amount payment)))
    )
    
    (print {
      event: "payment-settled",
      payment-id: payment-id,
      merchant: (get merchant payment),
      merchant-amount: merchant-amount,
      platform-fee: platform-fee
    })
    
    (ok true)
  )
)

;; Merchant withdrawal function
(define-public (withdraw-balance (amount uint))
  (let (
    (merchant tx-sender)
    (balance (get-merchant-balance merchant))
  )
    (asserts! (>= (get available balance) amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Update merchant balance
    (update-merchant-balance merchant (- 0 (to-int amount)) 0)
    
    (print {
      event: "balance-withdrawn",
      merchant: merchant,
      amount: amount
    })
    
    (ok true)
  )
)
