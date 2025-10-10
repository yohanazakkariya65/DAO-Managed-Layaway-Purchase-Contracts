(define-constant ERR_UNAUTHORIZED u400)
(define-constant ERR_INSUFFICIENT_POOL u401)
(define-constant ERR_ALREADY_INSURED u402)
(define-constant ERR_INVALID_CLAIM u403)
(define-constant ERR_CLAIM_EXISTS u404)

(define-constant PREMIUM_RATE u300)
(define-constant MIN_POOL_THRESHOLD u1000000)

(define-data-var insurance-pool-balance uint u0)
(define-data-var total-claims-paid uint u0)
(define-data-var pool-manager principal tx-sender)

(define-map insured-contracts
    uint
    {
        buyer: principal,
        contract-id: uint,
        total-price: uint,
        premium-paid: uint,
        coverage-start: uint,
        active: bool
    }
)

(define-map insurance-claims
    uint
    {
        contract-id: uint,
        claim-amount: uint,
        claimed-block: uint,
        status: (string-ascii 20)
    }
)

(define-public (purchase-insurance (contract-id uint) (total-price uint))
    (let
        ((premium (/ (* total-price PREMIUM_RATE) u10000)))
        (asserts! (is-none (map-get? insured-contracts contract-id)) (err ERR_ALREADY_INSURED))
        (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
        (var-set insurance-pool-balance (+ (var-get insurance-pool-balance) premium))
        (map-set insured-contracts contract-id {
            buyer: tx-sender,
            contract-id: contract-id,
            total-price: total-price,
            premium-paid: premium,
            coverage-start: stacks-block-height,
            active: true
        })
        (ok premium)
    )
)

(define-public (file-claim (contract-id uint) (amount-owed uint))
    (let
        ((insurance (unwrap! (map-get? insured-contracts contract-id) (err ERR_INVALID_CLAIM))))
        (asserts! (is-eq tx-sender (get buyer insurance)) (err ERR_UNAUTHORIZED))
        (asserts! (get active insurance) (err ERR_INVALID_CLAIM))
        (asserts! (<= amount-owed (get total-price insurance)) (err ERR_INVALID_CLAIM))
        (asserts! (>= (var-get insurance-pool-balance) amount-owed) (err ERR_INSUFFICIENT_POOL))
        (asserts! (is-none (map-get? insurance-claims contract-id)) (err ERR_CLAIM_EXISTS))
        (try! (as-contract (stx-transfer? amount-owed tx-sender (get buyer insurance))))
        (var-set insurance-pool-balance (- (var-get insurance-pool-balance) amount-owed))
        (var-set total-claims-paid (+ (var-get total-claims-paid) amount-owed))
        (map-set insured-contracts contract-id (merge insurance {active: false}))
        (map-set insurance-claims contract-id {
            contract-id: contract-id,
            claim-amount: amount-owed,
            claimed-block: stacks-block-height,
            status: "approved"
        })
        (ok amount-owed)
    )
)

(define-read-only (get-insurance-details (contract-id uint))
    (map-get? insured-contracts contract-id)
)

(define-read-only (get-pool-balance)
    (var-get insurance-pool-balance)
)

(define-read-only (calculate-premium (total-price uint))
    (/ (* total-price PREMIUM_RATE) u10000)
)

(define-read-only (get-claim (contract-id uint))
    (map-get? insurance-claims contract-id)
)