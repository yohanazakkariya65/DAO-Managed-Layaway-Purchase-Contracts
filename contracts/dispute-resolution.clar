(define-constant ERR_UNAUTHORIZED u300)
(define-constant ERR_DISPUTE_NOT_FOUND u301)
(define-constant ERR_ALREADY_VOTED u302)
(define-constant ERR_DISPUTE_RESOLVED u303)
(define-constant ERR_NOT_ARBITRATOR u304)

(define-constant MIN_ARBITRATORS u3)
(define-constant VOTING_PERIOD u144)

(define-data-var dispute-nonce uint u0)
(define-data-var arbitrator-fee uint u50000)

(define-map disputes
    uint
    {
        contract-id: uint,
        complainant: principal,
        respondent: principal,
        reason: (string-ascii 100),
        status: (string-ascii 20),
        created-block: uint,
        votes-for-complainant: uint,
        votes-for-respondent: uint,
        total-votes: uint,
        arbitrators-assigned: (list 5 principal)
    }
)

(define-map arbitrators principal bool)
(define-map dispute-votes {dispute-id: uint, arbitrator: principal} bool)

(define-public (register-arbitrator)
    (begin
        (try! (stx-transfer? (var-get arbitrator-fee) tx-sender (as-contract tx-sender)))
        (map-set arbitrators tx-sender true)
        (ok true)
    )
)

(define-public (create-dispute (contract-id uint) (respondent principal) (reason (string-ascii 100)))
    (let
        ((dispute-id (+ (var-get dispute-nonce) u1))
         (available-arbitrators (get-random-arbitrators)))
        (asserts! (>= (len available-arbitrators) MIN_ARBITRATORS) (err ERR_NOT_ARBITRATOR))
        (map-set disputes dispute-id {
            contract-id: contract-id,
            complainant: tx-sender,
            respondent: respondent,
            reason: reason,
            status: "active",
            created-block: stacks-block-height,
            votes-for-complainant: u0,
            votes-for-respondent: u0,
            total-votes: u0,
            arbitrators-assigned: available-arbitrators
        })
        (var-set dispute-nonce dispute-id)
        (ok dispute-id)
    )
)

(define-public (vote-on-dispute (dispute-id uint) (vote-for-complainant bool))
    (let
        ((dispute (unwrap! (map-get? disputes dispute-id) (err ERR_DISPUTE_NOT_FOUND))))
        (asserts! (default-to false (map-get? arbitrators tx-sender)) (err ERR_NOT_ARBITRATOR))
        (asserts! (is-some (index-of (get arbitrators-assigned dispute) tx-sender)) (err ERR_UNAUTHORIZED))
        (asserts! (is-eq (get status dispute) "active") (err ERR_DISPUTE_RESOLVED))
        (asserts! (is-none (map-get? dispute-votes {dispute-id: dispute-id, arbitrator: tx-sender})) (err ERR_ALREADY_VOTED))
        (asserts! (<= stacks-block-height (+ (get created-block dispute) VOTING_PERIOD)) (err ERR_DISPUTE_RESOLVED))
        (map-set dispute-votes {dispute-id: dispute-id, arbitrator: tx-sender} vote-for-complainant)
        (let
            ((new-complainant-votes (if vote-for-complainant (+ (get votes-for-complainant dispute) u1) (get votes-for-complainant dispute)))
             (new-respondent-votes (if vote-for-complainant (get votes-for-respondent dispute) (+ (get votes-for-respondent dispute) u1)))
             (new-total-votes (+ (get total-votes dispute) u1)))
            (map-set disputes dispute-id (merge dispute {
                votes-for-complainant: new-complainant-votes,
                votes-for-respondent: new-respondent-votes,
                total-votes: new-total-votes,
                status: (if (>= new-total-votes MIN_ARBITRATORS) 
                           (if (> new-complainant-votes new-respondent-votes) "complainant-wins" "respondent-wins")
                           "active")
            }))
        )
        (ok true)
    )
)

(define-read-only (get-dispute (dispute-id uint))
    (map-get? disputes dispute-id)
)

(define-read-only (is-arbitrator (user principal))
    (default-to false (map-get? arbitrators user))
)

(define-private (get-random-arbitrators)
    (list tx-sender tx-sender tx-sender)
)
