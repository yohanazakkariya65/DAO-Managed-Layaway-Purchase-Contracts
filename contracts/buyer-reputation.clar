(define-constant ERR_UNAUTHORIZED u200)
(define-constant ERR_INVALID_SCORE u201)
(define-constant ERR_NO_REPUTATION u202)

(define-constant POINTS_EARLY_PAYMENT u100)
(define-constant POINTS_ON_TIME_PAYMENT u50)
(define-constant DISCOUNT_THRESHOLD_BRONZE u500)
(define-constant DISCOUNT_THRESHOLD_SILVER u1500)
(define-constant DISCOUNT_THRESHOLD_GOLD u3000)

(define-map buyer-reputation 
    principal 
    {
        total-points: uint,
        early-payments: uint,
        on-time-payments: uint,
        late-payments: uint,
        total-contracts: uint,
        current-tier: (string-ascii 10)
    }
)

(define-map tier-discounts 
    (string-ascii 10) 
    uint
)

(define-data-var authorized-caller principal tx-sender)

(map-set tier-discounts "bronze" u50)
(map-set tier-discounts "silver" u125)
(map-set tier-discounts "gold" u250)

(define-public (set-authorized-caller (new-caller principal))
    (begin
        (asserts! (is-eq tx-sender (var-get authorized-caller)) (err ERR_UNAUTHORIZED))
        (var-set authorized-caller new-caller)
        (ok true)
    )
)

(define-public (record-payment-behavior (buyer principal) (is-early bool) (is-on-time bool))
    (begin
        (asserts! (is-eq tx-sender (var-get authorized-caller)) (err ERR_UNAUTHORIZED))
        (let 
            ((current-rep (default-to 
                {total-points: u0, early-payments: u0, on-time-payments: u0, 
                 late-payments: u0, total-contracts: u0, current-tier: "none"} 
                (map-get? buyer-reputation buyer)))
             (points-earned (if is-early POINTS_EARLY_PAYMENT 
                               (if is-on-time POINTS_ON_TIME_PAYMENT u0)))
             (new-points (+ (get total-points current-rep) points-earned))
             (new-tier (calculate-tier new-points)))
            (map-set buyer-reputation buyer {
                total-points: new-points,
                early-payments: (if is-early (+ (get early-payments current-rep) u1) (get early-payments current-rep)),
                on-time-payments: (if (and is-on-time (not is-early)) (+ (get on-time-payments current-rep) u1) (get on-time-payments current-rep)),
                late-payments: (if (and (not is-early) (not is-on-time)) (+ (get late-payments current-rep) u1) (get late-payments current-rep)),
                total-contracts: (+ (get total-contracts current-rep) u1),
                current-tier: new-tier
            })
            (ok points-earned)
        )
    )
)

(define-read-only (get-buyer-reputation (buyer principal))
    (map-get? buyer-reputation buyer)
)

(define-read-only (get-fee-discount (buyer principal))
    (match (map-get? buyer-reputation buyer)
        rep (default-to u0 (map-get? tier-discounts (get current-tier rep)))
        u0
    )
)

(define-read-only (calculate-tier (points uint))
    (if (>= points DISCOUNT_THRESHOLD_GOLD) "gold"
        (if (>= points DISCOUNT_THRESHOLD_SILVER) "silver"
            (if (>= points DISCOUNT_THRESHOLD_BRONZE) "bronze" "none")
        )
    )
)

(define-read-only (get-tier-requirements)
    {bronze: DISCOUNT_THRESHOLD_BRONZE, silver: DISCOUNT_THRESHOLD_SILVER, gold: DISCOUNT_THRESHOLD_GOLD}
)
