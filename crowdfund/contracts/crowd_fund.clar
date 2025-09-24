;; title: crowd_fund
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;; Core Campaign Management

;; Constants - Error Codes
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-campaign-ended (err u102))
(define-constant err-campaign-not-ended (err u103))
(define-constant err-goal-reached (err u104))
(define-constant err-goal-not-reached (err u105))
(define-constant err-insufficient-funds (err u106))
(define-constant err-invalid-amount (err u107))
(define-constant err-unauthorized (err u108))
(define-constant err-campaign-active (err u109))
(define-constant err-invalid-duration (err u110))
(define-constant err-invalid-title (err u130))
(define-constant err-invalid-description (err u131))
(define-constant err-invalid-goal (err u132))
(define-constant err-rate-limit-exceeded (err u133))
(define-constant err-contract-paused (err u134))
(define-constant err-invalid-category (err u135))
(define-constant err-kyc-required (err u136))

;; Platform Constants
(define-constant min-goal u1000000) ;; 1 STX minimum
(define-constant max-goal u1000000000000) ;; 1M STX maximum
(define-constant min-duration u144) ;; 1 day minimum
(define-constant max-duration u144000) ;; ~1000 days maximum
(define-constant max-title-length u100)
(define-constant max-description-length u500)
(define-constant platform-version u1)

;; Core Data Variables
(define-data-var campaign-counter uint u0)
(define-data-var total-campaigns uint u0)
(define-data-var total-funds-raised uint u0)
(define-data-var contract-paused bool false)
(define-data-var last-activity-block uint u0)

;; Rate Limiting
(define-data-var campaigns-per-block-limit uint u5)
(define-data-var contributions-per-block-limit uint u50)

;; Platform Statistics
(define-data-var successful-campaigns uint u0)
(define-data-var failed-campaigns uint u0)
(define-data-var platform-launch-block uint u0)

;; Core Data Maps
(define-map campaigns
    uint
    {
        title: (string-ascii 100),
        description: (string-ascii 500),
        creator: principal,
        goal: uint,
        raised: uint,
        end-block: uint,
        created-block: uint,
        status: (string-ascii 20),
        extensions-used: uint,
        max-extensions: uint,
        withdrawal-ready-block: uint,
        has-milestones: bool,
        category: (string-ascii 50),
        tags: (string-ascii 200),
        kyc-verified: bool,
        risk-level: uint,
        featured: bool,
    }
)

(define-map contributions
    {
        campaign-id: uint,
        contributor: principal,
    }
    uint
)

(define-map campaign-contributors
    uint
    (list 500 principal)
)

(define-map user-campaigns
    principal
    (list 100 uint)
)

(define-map user-contributions
    principal
    (list 100 uint)
)

;; New Advanced Maps
(define-map campaign-categories
    (string-ascii 50)
    {
        active: bool,
        campaign-count: uint,
        total-raised: uint,
    }
)

(define-map rate-limiting
    {
        user: principal,
        block-height: uint,
    }
    {
        campaigns-created: uint,
        contributions-made: uint,
    }
)

(define-map kyc-status
    principal
    {
        verified: bool,
        verification-block: uint,
        verification-level: uint,
    }
)

(define-map campaign-analytics
    uint
    {
        unique-contributors: uint,
        average-contribution: uint,
        contribution-velocity: uint,
        social-signals: uint,
    }
)

;; Input Validation Functions
(define-private (is-valid-title (title (string-ascii 100)))
    (and
        (> (len title) u0)
        (<= (len title) max-title-length)
        ;; Check for valid characters (no control characters)
        (is-some (index-of
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,!?-_()[]{}"
            (unwrap-panic (element-at title u0))
        ))
    )
)

(define-private (is-valid-description (description (string-ascii 500)))
    (and
        (> (len description) u10) ;; Minimum meaningful description
        (<= (len description) max-description-length)
    )
)

(define-private (is-valid-goal (goal uint))
    (and
        (>= goal min-goal)
        (<= goal max-goal)
    )
)

(define-private (is-valid-duration (duration uint))
    (and
        (>= duration min-duration)
        (<= duration max-duration)
    )
)

(define-private (is-valid-category (category (string-ascii 50)))
    (match (map-get? campaign-categories category)
        cat-info (get active cat-info)
        false
    )
)

(define-private (check-rate-limit
        (user principal)
        (action (string-ascii 20))
    )
    (let (
            (current-block stacks-block-height)
            (rate-data (map-get? rate-limiting {
                user: user,
                block-height: current-block,
            }))
        )
        (match rate-data
            data
            (if (is-eq action "campaign")
                (< (get campaigns-created data)
                    (var-get campaigns-per-block-limit)
                )
                (< (get contributions-made data)
                    (var-get contributions-per-block-limit)
                )
            )
            true ;; No previous activity this block
        )
    )
)

(define-private (update-rate-limit
        (user principal)
        (action (string-ascii 20))
    )
    (let (
            (current-block stacks-block-height)
            (current-data (default-to {
                campaigns-created: u0,
                contributions-made: u0,
            }
                (map-get? rate-limiting {
                    user: user,
                    block-height: current-block,
                })
            ))
        )
        (if (is-eq action "campaign")
            (map-set rate-limiting {
                user: user,
                block-height: current-block,
            }
                (merge current-data { campaigns-created: (+ (get campaigns-created current-data) u1) })
            )
            (map-set rate-limiting {
                user: user,
                block-height: current-block,
            }
                (merge current-data { contributions-made: (+ (get contributions-made current-data) u1) })
            )
        )
    )
)

;; Security Functions
(define-private (contract-not-paused)
    (not (var-get contract-paused))
)

;; Basic Read-only Functions
(define-read-only (get-campaign (campaign-id uint))
    (map-get? campaigns campaign-id)
)

(define-read-only (get-campaign-counter)
    (var-get campaign-counter)
)

(define-read-only (get-contribution
        (campaign-id uint)
        (contributor principal)
    )
    (default-to u0
        (map-get? contributions {
            campaign-id: campaign-id,
            contributor: contributor,
        })
    )
)

(define-read-only (is-campaign-active (campaign-id uint))
    (match (map-get? campaigns campaign-id)
        campaign (and
            (contract-not-paused)
            (< stacks-block-height (get end-block campaign))
            (is-eq (get status campaign) "active")
        )
        false
    )
)

(define-read-only (get-campaign-analytics (campaign-id uint))
    (map-get? campaign-analytics campaign-id)
)

(define-read-only (get-category-info (category (string-ascii 50)))
    (map-get? campaign-categories category)
)

(define-read-only (get-kyc-status (user principal))
    (map-get? kyc-status user)
)

(define-read-only (is-kyc-verified (user principal))
    (match (map-get? kyc-status user)
        status (get verified status)
        false
    )
)

(define-read-only (get-platform-stats)
    {
        total-campaigns: (var-get total-campaigns),
        successful-campaigns: (var-get successful-campaigns),
        failed-campaigns: (var-get failed-campaigns),
        total-funds-raised: (var-get total-funds-raised),
        contract-paused: (var-get contract-paused),
        platform-version: platform-version,
    }
)

(define-read-only (get-campaign-contributors (campaign-id uint))
    (default-to (list) (map-get? campaign-contributors campaign-id))
)

(define-read-only (get-user-campaigns (user principal))
    (default-to (list) (map-get? user-campaigns user))
)

(define-read-only (get-user-contributions (user principal))
    (default-to (list) (map-get? user-contributions user))
)

(define-read-only (get-total-campaigns)
    (var-get total-campaigns)
)

(define-read-only (get-total-funds-raised)
    (var-get total-funds-raised)
)

;; Helper Functions
(define-private (add-to-list
        (item uint)
        (current-list (list 100 uint))
    )
    (unwrap-panic (as-max-len? (append current-list item) u100))
)

(define-private (add-contributor
        (campaign-id uint)
        (contributor principal)
    )
    (let ((current-contributors (get-campaign-contributors campaign-id)))
        (if (is-none (index-of current-contributors contributor))
            (map-set campaign-contributors campaign-id
                (unwrap-panic (as-max-len? (append current-contributors contributor) u500))
            )
            true
        )
    )
)

(define-private (add-user-contribution
        (user principal)
        (campaign-id uint)
    )
    (let ((current-contributions (get-user-contributions user)))
        (if (is-none (index-of current-contributions campaign-id))
            (map-set user-contributions user
                (unwrap-panic (as-max-len? (append current-contributions campaign-id) u100))
            )
            true
        )
    )
)

(define-private (add-user-campaign
        (user principal)
        (campaign-id uint)
    )
    (let ((current-campaigns (get-user-campaigns user)))
        (map-set user-campaigns user
            (unwrap-panic (as-max-len? (append current-campaigns campaign-id) u100))
        )
    )
)

;; Core Public Functions
(define-public (create-campaign-advanced
        (title (string-ascii 100))
        (description (string-ascii 500))
        (goal uint)
        (duration uint)
        (category (string-ascii 50))
        (tags (string-ascii 200))
    )
    (let (
            (campaign-id (+ (var-get campaign-counter) u1))
            (end-block (+ stacks-block-height duration))
        )
        ;; Security and validation checks
        (asserts! (contract-not-paused) err-contract-paused)
        (asserts! (check-rate-limit tx-sender "campaign") err-rate-limit-exceeded)
        (asserts! (is-valid-title title) err-invalid-title)
        (asserts! (is-valid-description description) err-invalid-description)
        (asserts! (is-valid-goal goal) err-invalid-goal)
        (asserts! (is-valid-duration duration) err-invalid-duration)
        (asserts! (is-valid-category category) err-invalid-category)

        ;; Update rate limiting
        (update-rate-limit tx-sender "campaign")

        (map-set campaigns campaign-id {
            title: title,
            description: description,
            creator: tx-sender,
            goal: goal,
            raised: u0,
            end-block: end-block,
            created-block: stacks-block-height,
            status: "active",
            extensions-used: u0,
            max-extensions: u3,
            withdrawal-ready-block: u0,
            has-milestones: false,
            category: category,
            tags: tags,
            kyc-verified: (is-kyc-verified tx-sender),
            risk-level: u1, ;; Low risk by default
            featured: false,
        })

        ;; Update category stats
        (match (map-get? campaign-categories category)
            cat-info (map-set campaign-categories category
                (merge cat-info { campaign-count: (+ (get campaign-count cat-info) u1) })
            )
            false
        )

        ;; Initialize analytics
        (map-set campaign-analytics campaign-id {
            unique-contributors: u0,
            average-contribution: u0,
            contribution-velocity: u0,
            social-signals: u0,
        })

        (var-set campaign-counter campaign-id)
        (var-set total-campaigns (+ (var-get total-campaigns) u1))
        (add-user-campaign tx-sender campaign-id)

        (ok campaign-id)
    )
)

(define-public (contribute-advanced
        (campaign-id uint)
        (amount uint)
    )
    (let (
            (campaign (unwrap! (map-get? campaigns campaign-id) err-not-found))
            (new-raised (+ (get raised campaign) amount))
            (current-analytics (default-to {
                unique-contributors: u0,
                average-contribution: u0,
                contribution-velocity: u0,
                social-signals: u0,
            }
                (map-get? campaign-analytics campaign-id)
            ))
            (is-new-contributor (is-eq (get-contribution campaign-id tx-sender) u0))
        )
        ;; Enhanced validation
        (asserts! (contract-not-paused) err-contract-paused)
        (asserts! (check-rate-limit tx-sender "contribution")
            err-rate-limit-exceeded
        )
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (is-campaign-active campaign-id) err-campaign-ended)
        (asserts! (not (is-eq tx-sender (get creator campaign))) err-unauthorized)
        ;; Can't contribute to own campaign

        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

        ;; Update rate limiting
        (update-rate-limit tx-sender "contribution")

        (let ((existing-contribution (get-contribution campaign-id tx-sender)))
            (map-set contributions {
                campaign-id: campaign-id,
                contributor: tx-sender,
            }
                (+ existing-contribution amount)
            )
        )

        (map-set campaigns campaign-id (merge campaign { raised: new-raised }))
        (add-contributor campaign-id tx-sender)
        (add-user-contribution tx-sender campaign-id)
        (var-set total-funds-raised (+ (var-get total-funds-raised) amount))

        ;; Update analytics
        (let (
                (new-unique-contributors (if is-new-contributor
                    (+ (get unique-contributors current-analytics) u1)
                    (get unique-contributors current-analytics)
                ))
                (total-contributors (len (get-campaign-contributors campaign-id)))
                (new-avg-contribution (if (> total-contributors u0)
                    (/ new-raised total-contributors)
                    u0
                ))
            )
            (map-set campaign-analytics campaign-id {
                unique-contributors: new-unique-contributors,
                average-contribution: new-avg-contribution,
                contribution-velocity: (+ (get contribution-velocity current-analytics) u1),
                social-signals: (get social-signals current-analytics),
            })
        )

        ;; Update category stats
        (match (map-get? campaign-categories (get category campaign))
            cat-info (map-set campaign-categories (get category campaign)
                (merge cat-info { total-raised: (+ (get total-raised cat-info) amount) })
            )
            false
        )

        (ok amount)
    )
)

;; Batch Operations for Efficiency
(define-public (batch-contribute (campaign-amounts (list 10 {
    campaign-id: uint,
    amount: uint,
})))
    (let ((total-amount (fold + (map get-amount campaign-amounts) u0)))
        (asserts! (contract-not-paused) err-contract-paused)
        (asserts! (check-rate-limit tx-sender "contribution")
            err-rate-limit-exceeded
        )

        ;; Transfer total amount once
        (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))

        ;; Process each contribution
        (fold batch-contribute-helper campaign-amounts (ok u0))
    )
)

(define-private (get-amount (item {
    campaign-id: uint,
    amount: uint,
}))
    (get amount item)
)

(define-private (batch-contribute-helper
        (item {
            campaign-id: uint,
            amount: uint,
        })
        (previous-result (response uint uint))
    )
    (match previous-result
        success (contribute-internal (get campaign-id item) (get amount item))
        error (err error)
    )
)

(define-private (contribute-internal
        (campaign-id uint)
        (amount uint)
    )
    (let (
            (campaign (unwrap! (map-get? campaigns campaign-id) err-not-found))
            (new-raised (+ (get raised campaign) amount))
            (existing-contribution (get-contribution campaign-id tx-sender))
        )
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (is-campaign-active campaign-id) err-campaign-ended)

        (map-set contributions {
            campaign-id: campaign-id,
            contributor: tx-sender,
        }
            (+ existing-contribution amount)
        )

        (map-set campaigns campaign-id (merge campaign { raised: new-raised }))
        (add-contributor campaign-id tx-sender)
        (ok amount)
    )
)

;; Campaign Management Functions
(define-public (initialize-categories)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)

        ;; Initialize default categories
        (map-set campaign-categories "technology" {
            active: true,
            campaign-count: u0,
            total-raised: u0,
        })
        (map-set campaign-categories "art" {
            active: true,
            campaign-count: u0,
            total-raised: u0,
        })
        (map-set campaign-categories "health" {
            active: true,
            campaign-count: u0,
            total-raised: u0,
        })
        (map-set campaign-categories "education" {
            active: true,
            campaign-count: u0,
            total-raised: u0,
        })
        (map-set campaign-categories "environment" {
            active: true,
            campaign-count: u0,
            total-raised: u0,
        })
        (map-set campaign-categories "social" {
            active: true,
            campaign-count: u0,
            total-raised: u0,
        })

        (var-set platform-launch-block stacks-block-height)
        (ok true)
    )
)

;; KYC Management
(define-public (update-kyc-status
        (user principal)
        (verified bool)
        (level uint)
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)

        (map-set kyc-status user {
            verified: verified,
            verification-block: stacks-block-height,
            verification-level: level,
        })
        (ok true)
    )
)

(define-public (withdraw-funds (campaign-id uint))
    (let (
            (campaign (unwrap! (map-get? campaigns campaign-id) err-not-found))
            (raised-amount (get raised campaign))
        )
        (asserts! (is-eq tx-sender (get creator campaign)) err-unauthorized)
        (asserts! (>= stacks-block-height (get end-block campaign))
            err-campaign-active
        )
        (asserts! (>= raised-amount (get goal campaign)) err-goal-not-reached)

        (try! (as-contract (stx-transfer? raised-amount tx-sender (get creator campaign))))
        (map-set campaigns campaign-id (merge campaign { status: "completed" }))

        (ok raised-amount)
    )
)

(define-public (claim-refund (campaign-id uint))
    (let (
            (campaign (unwrap! (map-get? campaigns campaign-id) err-not-found))
            (contribution (get-contribution campaign-id tx-sender))
        )
        (asserts! (> contribution u0) err-insufficient-funds)
        (asserts! (>= stacks-block-height (get end-block campaign))
            err-campaign-active
        )
        (asserts! (< (get raised campaign) (get goal campaign)) err-goal-reached)

        (try! (as-contract (stx-transfer? contribution tx-sender tx-sender)))
        (map-delete contributions {
            campaign-id: campaign-id,
            contributor: tx-sender,
        })

        (ok contribution)
    )
)
