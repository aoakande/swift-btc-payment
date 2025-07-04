;; SwiftBTC Merchant Registry Contract
;; Manages merchant registration, verification, and profile management

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u200))
(define-constant ERR-MERCHANT-NOT-FOUND (err u201))
(define-constant ERR-MERCHANT-ALREADY-EXISTS (err u202))
(define-constant ERR-INVALID-MERCHANT-DATA (err u203))
(define-constant ERR-MERCHANT-SUSPENDED (err u204))
(define-constant ERR-VERIFICATION-PENDING (err u205))
(define-constant ERR-INVALID-STATUS (err u206))
(define-constant ERR-INSUFFICIENT-STAKE (err u207))

;; Merchant status constants
(define-constant STATUS-PENDING u0)
(define-constant STATUS-VERIFIED u1)
(define-constant STATUS-SUSPENDED u2)
(define-constant STATUS-BANNED u3)

;; Merchant tier constants
(define-constant TIER-BASIC u0)
(define-constant TIER-PREMIUM u1)
(define-constant TIER-ENTERPRISE u2)

;; Data Variables
(define-data-var merchant-counter uint u0)
(define-data-var minimum-stake-amount uint u1000000) ;; 1 STX in microSTX
(define-data-var verification-fee uint u100000) ;; 0.1 STX in microSTX
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
    verified-at: (optional uint),
    last-activity: uint,
    total-payments: uint,
    total-volume: uint,
    reputation-score: uint
  }
)

(define-map merchant-settings
  { merchant-address: principal }
  {
    auto-settle: bool,
    settlement-delay: uint,
    webhook-url: (optional (string-ascii 256)),
    notification-email: (optional (string-ascii 64)),
    custom-fee-rate: (optional uint),
    payment-timeout: uint
  }
)

(define-map merchant-stakes
  { merchant-address: principal }
  { staked-amount: uint, stake-locked-until: uint }
)

(define-map merchant-verifiers
  { verifier: principal }
  { authorized: bool, verification-count: uint }
)

(define-map verification-requests
  { merchant-address: principal }
  {
    requested-at: uint,
    verifier: (optional principal),
    verified-at: (optional uint),
    verification-notes: (optional (string-ascii 256)),
    documents-hash: (optional (buff 32))
  }
)

;; Read-only functions
(define-read-only (get-merchant (merchant-address principal))
  (map-get? merchants { merchant-address: merchant-address })
)

(define-read-only (get-merchant-settings (merchant-address principal))
  (default-to 
    {
      auto-settle: true,
      settlement-delay: u6, ;; 6 blocks default
      webhook-url: none,
      notification-email: none,
      custom-fee-rate: none,
      payment-timeout: u144 ;; 24 hours in blocks
    }
    (map-get? merchant-settings { merchant-address: merchant-address })
  )
)

(define-read-only (get-merchant-stake (merchant-address principal))
  (map-get? merchant-stakes { merchant-address: merchant-address })
)

(define-read-only (is-merchant-active (merchant-address principal))
  (match (get-merchant merchant-address)
    merchant (and 
      (is-eq (get status merchant) STATUS-VERIFIED)
      (> (get last-activity merchant) (- stacks-block-height u1440)) ;; Active within 10 days
    )
    false
  )
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


(define-private (min (a uint) (b uint))
  (if (< a b) a b)
)

(define-read-only (calculate-reputation-score (total-payments uint) (total-volume uint) (days-active uint))
  (let (
    (payment-score (min (* total-payments u2) u200))
    (volume-score (min (/ total-volume u1000000) u300))
    (activity-score (min (* days-active u1) u100))
  )
    (+ payment-score volume-score activity-score)
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
        verified-at: none,
        last-activity: stacks-block-height,
        total-payments: u0,
        total-volume: u0,
        reputation-score: u0
      }
    )
    
    ;; Set default settings
    (map-set merchant-settings
      { merchant-address: merchant-address }
      {
        auto-settle: true,
        settlement-delay: u6,
        webhook-url: none,
        notification-email: (some contact-email),
        custom-fee-rate: none,
        payment-timeout: u144
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

;; Update merchant profile
(define-public (update-merchant-profile
  (business-name (string-ascii 64))
  (business-type (string-ascii 32))
  (contact-email (string-ascii 64))
  (website (optional (string-ascii 128)))
  (description (string-ascii 256))
)
  (let (
    (merchant-address tx-sender)
    (merchant (unwrap! (get-merchant merchant-address) ERR-MERCHANT-NOT-FOUND))
  )
    (asserts! (validate-merchant-data business-name business-type contact-email) ERR-INVALID-MERCHANT-DATA)
    (asserts! (not (is-eq (get status merchant) STATUS-BANNED)) ERR-MERCHANT-SUSPENDED)
    
    (map-set merchants
      { merchant-address: merchant-address }
      (merge merchant {
        business-name: business-name,
        business-type: business-type,
        contact-email: contact-email,
        website: website,
        description: description,
        last-activity: stacks-block-height
      })
    )
    
    (print {
      event: "merchant-profile-updated",
      merchant-address: merchant-address
    })
    
    (ok true)
  )
)

;; Update merchant settings
(define-public (update-merchant-settings
  (auto-settle bool)
  (settlement-delay uint)
  (webhook-url (optional (string-ascii 256)))
  (notification-email (optional (string-ascii 64)))
  (payment-timeout uint)
)
  (let (
    (merchant-address tx-sender)
  )
    (asserts! (is-some (get-merchant merchant-address)) ERR-MERCHANT-NOT-FOUND)
    (asserts! (<= settlement-delay u144) ERR-INVALID-MERCHANT-DATA) ;; Max 24 hours
    (asserts! (<= payment-timeout u1440) ERR-INVALID-MERCHANT-DATA) ;; Max 10 days
    
    (map-set merchant-settings
      { merchant-address: merchant-address }
      {
        auto-settle: auto-settle,
        settlement-delay: settlement-delay,
        webhook-url: webhook-url,
        notification-email: notification-email,
        custom-fee-rate: none, ;; Admin only
        payment-timeout: payment-timeout
      }
    )
    
    (print {
      event: "merchant-settings-updated",
      merchant-address: merchant-address
    })
    
    (ok true)
  )
)

;; Request verification
(define-public (request-verification (documents-hash (buff 32)))
  (let (
    (merchant-address tx-sender)
    (merchant (unwrap! (get-merchant merchant-address) ERR-MERCHANT-NOT-FOUND))
  )
    (asserts! (is-eq (get status merchant) STATUS-PENDING) ERR-INVALID-STATUS)
    
    (map-set verification-requests
      { merchant-address: merchant-address }
      {
        requested-at: stacks-block-height,
        verifier: none,
        verified-at: none,
        verification-notes: none,
        documents-hash: (some documents-hash)
      }
    )
    
    (print {
      event: "verification-requested",
      merchant-address: merchant-address,
      documents-hash: documents-hash
    })
    
    (ok true)
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

;; Admin functions

;; Verify merchant (admin only)
(define-public (verify-merchant 
  (merchant-address principal) 
  (verifier principal)
  (verification-notes (string-ascii 256))
)
  (let (
    (merchant (unwrap! (get-merchant merchant-address) ERR-MERCHANT-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status merchant) STATUS-PENDING) ERR-INVALID-STATUS)
    
    ;; Update merchant status
    (map-set merchants
      { merchant-address: merchant-address }
      (merge merchant {
        status: STATUS-VERIFIED,
        verified-at: (some stacks-block-height)
      })
    )
    
    ;; Update verification request
    (map-set verification-requests
      { merchant-address: merchant-address }
      (merge 
        (default-to 
          { requested-at: stacks-block-height, verifier: none, verified-at: none, verification-notes: none, documents-hash: none }
          (map-get? verification-requests { merchant-address: merchant-address })
        )
        {
          verifier: (some verifier),
          verified-at: (some stacks-block-height),
          verification-notes: (some verification-notes)
        }
      )
    )
    
    (print {
      event: "merchant-verified",
      merchant-address: merchant-address,
      verifier: verifier
    })
    
    (ok true)
  )
)

;; Suspend merchant (admin only)
(define-public (suspend-merchant (merchant-address principal) (reason (string-ascii 256)))
  (let (
    (merchant (unwrap! (get-merchant merchant-address) ERR-MERCHANT-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    
    (map-set merchants
      { merchant-address: merchant-address }
      (merge merchant { status: STATUS-SUSPENDED })
    )
    
    (print {
      event: "merchant-suspended",
      merchant-address: merchant-address,
      reason: reason
    })
    
    (ok true)
  )
)
