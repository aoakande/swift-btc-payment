;; SwiftBTC Merchant Registry Contract
;; Manages merchant registration, verification, and profile management

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-MERCHANT-NOT-FOUND (err u201))
(define-constant ERR-MERCHANT-ALREADY-EXISTS (err u202))
(define-constant ERR-INVALID-MERCHANT-DATA (err u203))
(define-constant ERR-INSUFFICIENT-STAKE (err u207))

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
(define-data-var premium-tier-stake uint u10000000) ;; 10 STX for premium
(define-data-var enterprise-tier-stake uint u50000000) ;; 50 STX for enterprise

;; Data Maps
(define-map merchants
  { merchant-address: principal }
  {
    merchant-id: uint,
    business-name: (string-ascii 64),
    business-type: (string-ascii 32),
    contact-email: (string-ascii 64),
    website: (optional (string-ascii 128)),
    description: (string-ascii 256),
    status: uint,
    tier: uint,
    stake-amount: uint,
    created-at: uint,
    last-activity: uint
  }
)

(define-map merchant-stakes
  { merchant-address: principal }
  { staked-amount: uint, stake-locked-until: uint }
)

;; Read-only functions
(define-read-only (get-merchant (merchant-address principal))
  (map-get? merchants { merchant-address: merchant-address })
)

(define-read-only (get-merchant-stake (merchant-address principal))
  (map-get? merchant-stakes { merchant-address: merchant-address })
)

(define-read-only (is-merchant-verified (merchant-address principal))
  (match (get-merchant merchant-address)
    merchant (is-eq (get status merchant) STATUS-VERIFIED)
    false
  )
)

(define-read-only (get-merchant-tier-requirements (tier uint))
  (if (is-eq tier TIER-BASIC)
    { stake-required: (var-get minimum-stake-amount), benefits: "Basic payment processing" }
    (if (is-eq tier TIER-PREMIUM)
      { stake-required: (var-get premium-tier-stake), benefits: "Lower fees, priority support" }
      { stake-required: (var-get enterprise-tier-stake), benefits: "Custom features, dedicated support" }
    )
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

(define-private (determine-tier-by-stake (stake-amount uint))
  (if (>= stake-amount (var-get enterprise-tier-stake))
    TIER-ENTERPRISE
    (if (>= stake-amount (var-get premium-tier-stake))
      TIER-PREMIUM
      TIER-BASIC
    )
  )
)

;; Public functions

;; Register as a new merchant
(define-public (register-merchant
  (business-name (string-ascii 64))
  (business-type (string-ascii 32))
  (contact-email (string-ascii 64))
  (website (optional (string-ascii 128)))
  (description (string-ascii 256))
  (stake-amount uint)
)
  (let (
    (merchant-address tx-sender)
    (merchant-id (increment-merchant-counter))
    (tier (determine-tier-by-stake stake-amount))
  )
    (asserts! (is-none (get-merchant merchant-address)) ERR-MERCHANT-ALREADY-EXISTS)
    (asserts! (validate-merchant-data business-name business-type contact-email) ERR-INVALID-MERCHANT-DATA)
    (asserts! (>= stake-amount (var-get minimum-stake-amount)) ERR-INSUFFICIENT-STAKE)
    
    ;; Stake STX tokens (in production, transfer to escrow)
    (map-set merchant-stakes
      { merchant-address: merchant-address }
      { 
        staked-amount: stake-amount,
        stake-locked-until: (+ stacks-block-height u2016) ;; Locked for ~2 weeks
      }
    )
    
    ;; Create merchant profile
    (map-set merchants
      { merchant-address: merchant-address }
      {
        merchant-id: merchant-id,
        business-name: business-name,
        business-type: business-type,
        contact-email: contact-email,
        website: website,
        description: description,
        status: STATUS-PENDING,
        tier: tier,
        stake-amount: stake-amount,
        created-at: stacks-block-height,
        last-activity: stacks-block-height
      }
    )
    
    (print {
      event: "merchant-registered",
      merchant-id: merchant-id,
      merchant-address: merchant-address,
      business-name: business-name,
      tier: tier,
      stake-amount: stake-amount
    })
    
    (ok merchant-id)
  )
)

;; Increase stake to upgrade tier
(define-public (upgrade-tier (additional-stake uint))
  (let (
    (merchant-address tx-sender)
    (merchant (unwrap! (get-merchant merchant-address) ERR-MERCHANT-NOT-FOUND))
    (current-stake (get stake-amount merchant))
    (new-stake (+ current-stake additional-stake))
    (new-tier (determine-tier-by-stake new-stake))
  )
    (asserts! (> additional-stake u0) ERR-INVALID-MERCHANT-DATA)
    (asserts! (> new-tier (get tier merchant)) ERR-INVALID-MERCHANT-DATA)
    
    ;; Update stake
    (map-set merchant-stakes
      { merchant-address: merchant-address }
      {
        staked-amount: new-stake,
        stake-locked-until: (+ stacks-block-height u2016)
      }
    )
    
    ;; Update merchant tier
    (map-set merchants
      { merchant-address: merchant-address }
      (merge merchant {
        tier: new-tier,
        stake-amount: new-stake,
        last-activity: stacks-block-height
      })
    )
    
    (print {
      event: "tier-upgraded",
      merchant-address: merchant-address,
      old-tier: (get tier merchant),
      new-tier: new-tier,
      new-stake: new-stake
    })
    
    (ok new-tier)
  )
)
