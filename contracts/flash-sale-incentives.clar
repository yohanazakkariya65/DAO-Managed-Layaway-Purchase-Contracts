(define-constant ERR_UNAUTHORIZED u500)
(define-constant ERR_SALE_NOT_FOUND u501)
(define-constant ERR_SALE_EXPIRED u502)
(define-constant ERR_SALE_ACTIVE u503)
(define-constant ERR_INVALID_PARAMETERS u504)
(define-constant ERR_ALREADY_CLAIMED u505)

(define-data-var sale-nonce uint u0)
(define-data-var contract-admin principal tx-sender)

(define-map flash-sales
    uint
    {
        seller: principal,
        contract-id: uint,
        discount-rate: uint,
        start-block: uint,
        end-block: uint,
        max-claims: uint,
        claims-used: uint,
        total-savings: uint,
        active: bool
    }
)

(define-map sale-claims
    {sale-id: uint, buyer: principal}
    {
        claimed-block: uint,
        discount-amount: uint
    }
)

(define-map seller-sales principal (list 20 uint))

(define-public (create-flash-sale 
    (contract-id uint)
    (discount-rate uint)
    (duration-blocks uint)
    (max-claims uint))
    (let
        ((sale-id (+ (var-get sale-nonce) u1))
         (end-block (+ stacks-block-height duration-blocks)))
        (asserts! (> discount-rate u0) (err ERR_INVALID_PARAMETERS))
        (asserts! (<= discount-rate u5000) (err ERR_INVALID_PARAMETERS))
        (asserts! (> duration-blocks u0) (err ERR_INVALID_PARAMETERS))
        (asserts! (> max-claims u0) (err ERR_INVALID_PARAMETERS))
        (map-set flash-sales sale-id {
            seller: tx-sender,
            contract-id: contract-id,
            discount-rate: discount-rate,
            start-block: stacks-block-height,
            end-block: end-block,
            max-claims: max-claims,
            claims-used: u0,
            total-savings: u0,
            active: true
        })
        (var-set sale-nonce sale-id)
        (update-seller-sales tx-sender sale-id)
        (ok sale-id)
    )
)

(define-public (claim-discount (sale-id uint) (payment-amount uint))
    (let
        ((sale (unwrap! (map-get? flash-sales sale-id) (err ERR_SALE_NOT_FOUND)))
         (discount (/ (* payment-amount (get discount-rate sale)) u10000)))
        (asserts! (get active sale) (err ERR_SALE_EXPIRED))
        (asserts! (<= stacks-block-height (get end-block sale)) (err ERR_SALE_EXPIRED))
        (asserts! (< (get claims-used sale) (get max-claims sale)) (err ERR_SALE_EXPIRED))
        (asserts! (is-none (map-get? sale-claims {sale-id: sale-id, buyer: tx-sender})) (err ERR_ALREADY_CLAIMED))
        (map-set sale-claims {sale-id: sale-id, buyer: tx-sender} {
            claimed-block: stacks-block-height,
            discount-amount: discount
        })
        (map-set flash-sales sale-id (merge sale {
            claims-used: (+ (get claims-used sale) u1),
            total-savings: (+ (get total-savings sale) discount)
        }))
        (ok discount)
    )
)

(define-public (deactivate-sale (sale-id uint))
    (let
        ((sale (unwrap! (map-get? flash-sales sale-id) (err ERR_SALE_NOT_FOUND))))
        (asserts! (is-eq tx-sender (get seller sale)) (err ERR_UNAUTHORIZED))
        (asserts! (get active sale) (err ERR_SALE_EXPIRED))
        (map-set flash-sales sale-id (merge sale {active: false}))
        (ok true)
    )
)

(define-read-only (get-flash-sale (sale-id uint))
    (map-get? flash-sales sale-id)
)

(define-read-only (get-claim-status (sale-id uint) (buyer principal))
    (map-get? sale-claims {sale-id: sale-id, buyer: buyer})
)

(define-read-only (get-seller-sales (seller principal))
    (default-to (list) (map-get? seller-sales seller))
)

(define-read-only (calculate-discount (sale-id uint) (amount uint))
    (match (map-get? flash-sales sale-id)
        sale (ok (/ (* amount (get discount-rate sale)) u10000))
        (err ERR_SALE_NOT_FOUND)
    )
)

(define-private (update-seller-sales (seller principal) (sale-id uint))
    (let
        ((current-sales (default-to (list) (map-get? seller-sales seller))))
        (map-set seller-sales seller (unwrap-panic (as-max-len? (append current-sales sale-id) u20)))
    )
)
