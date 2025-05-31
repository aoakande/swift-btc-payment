;; SwiftBTC Payment Processor Contract
;; Core contract for sBTC-native payment processing with sub-10s settlement

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-PAYMENT (err u101))
(define-constant ERR-PAYMENT-NOT-FOUND (err u102))
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
    amount: uint,
    sbtc-amount: uint,
    status: uint,
    created-at: uint,
    expires-at: uint,
    payment-reference: (string-ascii 64)
  }
)

;; Read-only functions
(define-read-only (get-payment (payment-id uint))
  (map-get? payments { payment-id: payment-id })
)

(define-read-only (get-current-payment-counter)
  (var-get payment-counter)
)

;; Private functions
(define-private (increment-payment-counter)
  (let ((current (var-get payment-counter)))
    (var-set payment-counter (+ current u1))
    (+ current u1)
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
        amount: amount,
        sbtc-amount: sbtc-amount,
        status: STATUS-PENDING,
        created-at: stacks-block-height,
        expires-at: expires-at,
        payment-reference: payment-reference
      }
    )
    
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
