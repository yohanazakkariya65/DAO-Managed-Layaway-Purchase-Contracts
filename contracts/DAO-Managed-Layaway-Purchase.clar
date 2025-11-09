(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_INVALID_AMOUNT u101)
(define-constant ERR_CONTRACT_NOT_FOUND u102)
(define-constant ERR_PAYMENT_FAILED u103)
(define-constant ERR_ALREADY_PAID u104)
(define-constant ERR_OVERDUE u105)
(define-constant ERR_NOT_READY u106)

(define-data-var dao-treasury principal CONTRACT_OWNER)
(define-data-var dao-fee-rate uint u250)
(define-data-var contract-nonce uint u0)

(define-map layaway-contracts
    uint
    {
        buyer: principal,
        seller: principal,
        item-id: uint,
        total-price: uint,
        paid-amount: uint,
        payment-schedule: uint,
        installments: uint,
        installments-paid: uint,
        start-block: uint,
        end-block: uint,
        status: (string-ascii 20),
        dao-held: bool
    }
)

(define-map buyer-contracts principal (list 50 uint))
(define-map seller-contracts principal (list 50 uint))

(define-public (create-layaway-contract 
    (seller principal)
    (item-id uint)
    (total-price uint)
    (installments uint)
    (payment-schedule uint))
    (let
        ((contract-id (+ (var-get contract-nonce) u1))
         (end-block (+ stacks-block-height (* installments payment-schedule))))
        (asserts! (> total-price u0) (err ERR_INVALID_AMOUNT))
        (asserts! (> installments u0) (err ERR_INVALID_AMOUNT))
        (asserts! (> payment-schedule u0) (err ERR_INVALID_AMOUNT))
        (map-set layaway-contracts contract-id {
            buyer: tx-sender,
            seller: seller,
            item-id: item-id,
            total-price: total-price,
            paid-amount: u0,
            payment-schedule: payment-schedule,
            installments: installments,
            installments-paid: u0,
            start-block: stacks-block-height,
            end-block: end-block,
            status: "active",
            dao-held: false
        })
        (var-set contract-nonce contract-id)
        (update-buyer-contracts tx-sender contract-id)
        (update-seller-contracts seller contract-id)
        (ok contract-id)
    )
)

(define-public (make-payment (contract-id uint) (amount uint))
    (let
        ((contract (unwrap! (map-get? layaway-contracts contract-id) (err ERR_CONTRACT_NOT_FOUND)))
         (installment-amount (/ (get total-price contract) (get installments contract)))
         (dao-fee (/ (* amount (var-get dao-fee-rate)) u10000)))
        (asserts! (is-eq tx-sender (get buyer contract)) (err ERR_UNAUTHORIZED))
        (asserts! (is-eq (get status contract) "active") (err ERR_PAYMENT_FAILED))
        (asserts! (>= amount installment-amount) (err ERR_INVALID_AMOUNT))
        (asserts! (<= stacks-block-height (get end-block contract)) (err ERR_OVERDUE))
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (try! (stx-transfer? dao-fee (as-contract tx-sender) (var-get dao-treasury)))
        (let
            ((new-paid (+ (get paid-amount contract) amount))
             (new-installments-paid (+ (get installments-paid contract) u1)))
            (if (>= new-paid (get total-price contract))
                (map-set layaway-contracts contract-id (merge contract {
                    paid-amount: new-paid,
                    installments-paid: new-installments-paid,
                    status: "completed"
                }))
                (map-set layaway-contracts contract-id (merge contract {
                    paid-amount: new-paid,
                    installments-paid: new-installments-paid
                }))
            )
        )
        (ok true)
    )
)

(define-public (dao-hold-item (contract-id uint))
    (let
        ((contract (unwrap! (map-get? layaway-contracts contract-id) (err ERR_CONTRACT_NOT_FOUND))))
        (asserts! (is-eq tx-sender (get seller contract)) (err ERR_UNAUTHORIZED))
        (asserts! (is-eq (get status contract) "active") (err ERR_NOT_READY))
        (map-set layaway-contracts contract-id (merge contract {dao-held: true}))
        (ok true)
    )
)

(define-public (release-item (contract-id uint))
    (let
        ((contract (unwrap! (map-get? layaway-contracts contract-id) (err ERR_CONTRACT_NOT_FOUND)))
         (payment-to-seller (- (get paid-amount contract) (/ (* (get paid-amount contract) (var-get dao-fee-rate)) u10000))))
        (asserts! (is-eq (get status contract) "completed") (err ERR_NOT_READY))
        (asserts! (get dao-held contract) (err ERR_NOT_READY))
        (try! (as-contract (stx-transfer? payment-to-seller tx-sender (get seller contract))))
        (map-set layaway-contracts contract-id (merge contract {status: "released"}))
        (ok true)
    )
)

(define-public (cancel-contract (contract-id uint))
    (let
        ((contract (unwrap! (map-get? layaway-contracts contract-id) (err ERR_CONTRACT_NOT_FOUND))))
        (asserts! (or (is-eq tx-sender (get buyer contract)) (is-eq tx-sender (get seller contract))) (err ERR_UNAUTHORIZED))
        (asserts! (is-eq (get status contract) "active") (err ERR_NOT_READY))
        (if (> (get paid-amount contract) u0)
            (try! (as-contract (stx-transfer? (get paid-amount contract) tx-sender (get buyer contract))))
            true
        )
        (map-set layaway-contracts contract-id (merge contract {status: "cancelled"}))
        (ok true)
    )
)

(define-public (handle-default (contract-id uint))
    (let
        ((contract (unwrap! (map-get? layaway-contracts contract-id) (err ERR_CONTRACT_NOT_FOUND))))
        (asserts! (> stacks-block-height (get end-block contract)) (err ERR_NOT_READY))
        (asserts! (is-eq (get status contract) "active") (err ERR_NOT_READY))
        (if (> (get paid-amount contract) u0)
            (try! (as-contract (stx-transfer? (get paid-amount contract) tx-sender (get seller contract))))
            true
        )
        (map-set layaway-contracts contract-id (merge contract {status: "defaulted"}))
        (ok true)
    )
)

(define-public (set-dao-treasury (new-treasury principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_UNAUTHORIZED))
        (var-set dao-treasury new-treasury)
        (ok true)
    )
)

(define-public (set-dao-fee-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) (err ERR_UNAUTHORIZED))
        (asserts! (<= new-rate u1000) (err ERR_INVALID_AMOUNT))
        (var-set dao-fee-rate new-rate)
        (ok true)
    )
)

(define-read-only (get-contract (contract-id uint))
    (map-get? layaway-contracts contract-id)
)

(define-read-only (get-buyer-contracts (buyer principal))
    (default-to (list) (map-get? buyer-contracts buyer))
)

(define-read-only (get-seller-contracts (seller principal))
    (default-to (list) (map-get? seller-contracts seller))
)

(define-read-only (get-dao-treasury)
    (var-get dao-treasury)
)

(define-read-only (get-dao-fee-rate)
    (var-get dao-fee-rate)
)

(define-private (update-buyer-contracts (buyer principal) (contract-id uint))
    (let
        ((current-contracts (default-to (list) (map-get? buyer-contracts buyer))))
        (map-set buyer-contracts buyer (unwrap-panic (as-max-len? (append current-contracts contract-id) u50)))
    )
)

(define-private (update-seller-contracts (seller principal) (contract-id uint))
    (let
        ((current-contracts (default-to (list) (map-get? seller-contracts seller))))
        (map-set seller-contracts seller (unwrap-panic (as-max-len? (append current-contracts contract-id) u50)))
    )
)
