;; SwiftBTC Payment Processor Contract
;; Core contract for sBTC-native payment processing with sub-10s settlement

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-PAYMENT (err u101))
(define-constant ERR-PAYMENT-NOT-FOUND (err u102))

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
    status: uint,
    created-at: uint
  }
)

;; Read-only functions
(define-read-only (get-payment (payment-id uint))
  (map-get? payments { payment-id: payment-id })
)

(define-read-only (get-current-payment-counter)
  (var-get payment-counter)
)
