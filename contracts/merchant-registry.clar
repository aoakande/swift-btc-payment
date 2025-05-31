;; SwiftBTC Merchant Registry Contract
;; Manages merchant registration, verification, and profile management

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-MERCHANT-NOT-FOUND (err u201))
(define-constant ERR-MERCHANT-ALREADY-EXISTS (err u202))
(define-constant ERR-INVALID-MERCHANT-DATA (err u203))

;; Merchant status constants
(define-constant STATUS-PENDING u0)
(define-constant STATUS-VERIFIED u1)
(define-constant STATUS-SUSPENDED u2)

;; Merchant tier constants
(define-constant TIER-BASIC u0)
(define-constant TIER-PREMIUM u1)
(define-constant TIER-ENTERPRISE u2)

;; Data Variables
(define-data-var merchant-counter uint u0)
(define-data-var minimum-stake-amount uint u1000000) ;; 1 STX in microSTX

;; Data Maps
(define-map merchants
  { merchant-address: principal }
  {
    merchant-id: uint,
    business-name: (string-ascii 64),
    business-type: (string-ascii 32),
    contact-email: (string-ascii 64),
    status: uint,
    tier: uint,
    stake-amount: uint,
    created-at: uint
  }
)

;; Read-only functions
(define-read-only (get-merchant (merchant-address principal))
  (map-get? merchants { merchant-address: merchant-address })
)

(define-read-only (is-merchant-verified (merchant-address principal))
  (match (get-merchant merchant-address)
    merchant (is-eq (get status merchant) STATUS-VERIFIED)
    false
  )
)

;; Private functions
(define-private (increment-merchant-counter)
  (let ((current (var-get merchant-counter)))
    (var-set merchant-counter (+ current u1))
    (+ current u1)
  )
)

(define-private (validate-merchant-data 
  (business-name (string-ascii 64))
  (business-type (string-ascii 32))
  (contact-email (string-ascii 64))
)
  (and
    (> (len business-name) u0)
    (> (len business-type) u0)
    (> (len contact-email) u5) ;; Basic email validation
  )
)

;; Public functions

;; Register as a new merchant
(define-public (register-merchant
  (business-name (string-ascii 64))
  (business-type (string-ascii 32))
  (contact-email (string-ascii 64))
  (stake-amount uint)
)
  (let (
    (merchant-address tx-sender)
    (merchant-id (increment-merchant-counter))
  )
    (asserts! (is-none (get-merchant merchant-address)) ERR-MERCHANT-ALREADY-EXISTS)
    (asserts! (validate-merchant-data business-name business-type contact-email) ERR-INVALID-MERCHANT-DATA)
    (asserts! (>= stake-amount (var-get minimum-stake-amount)) ERR-INVALID-MERCHANT-DATA)
    
    ;; Create merchant profile
    (map-set merchants
      { merchant-address: merchant-address }
      {
        merchant-id: merchant-id,
        business-name: business-name,
        business-type: business-type,
        contact-email: contact-email,
        status: STATUS-PENDING,
        tier: TIER-BASIC,
        stake-amount: stake-amount,
        created-at: stacks-block-height
      }
    )
    
    (print {
      event: "merchant-registered",
      merchant-id: merchant-id,
      merchant-address: merchant-address,
      business-name: business-name
    })
    
    (ok merchant-id)
  )
)
