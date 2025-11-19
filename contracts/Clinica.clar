;; title: Clinica
;; version: 2.0.0
;; summary: Clinical Trial Data Verifier - ensuring data integrity and transparency with multi-signature approval gates

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-data (err u103))
(define-constant err-trial-exists (err u104))
(define-constant err-trial-not-active (err u105))
(define-constant err-patient-exists (err u106))
(define-constant err-invalid-status (err u107))
(define-constant err-insufficient-funds (err u108))
(define-constant err-reward-already-claimed (err u109))
(define-constant err-no-rewards-available (err u110))
(define-constant err-multi-sig-required (err u111))
(define-constant err-approver-already-signed (err u112))
(define-constant err-invalid-threshold (err u113))
(define-constant err-not-approver (err u114))

(define-data-var next-trial-id uint u1)
(define-data-var next-patient-id uint u1)
(define-data-var next-data-entry-id uint u1)
(define-data-var next-reward-pool-id uint u1)

(define-map checkpoint-configs
    { trial-id: uint }
    {
        interval-blocks: uint,
        verification-threshold: uint
    }
)

(define-map audit-checkpoints
    { checkpoint-id: uint }
    {
        trial-id: uint,
        block-created: uint,
        verified-count: uint,
        total-count: uint,
        passed: bool,
        verifier: principal
    }
)

(define-data-var next-checkpoint-id uint u0)

(define-map trials
    uint
    {
        title: (string-ascii 100),
        principal-investigator: principal,
        institution: (string-ascii 100),
        start-block: uint,
        end-block: uint,
        status: (string-ascii 20),
        patient-count: uint,
        data-entries: uint
    }
)

(define-map trial-permissions
    { trial-id: uint, user: principal }
    { role: (string-ascii 20), granted-at: uint }
)

(define-map patients
    uint
    {
        trial-id: uint,
        patient-identifier: (string-ascii 50),
        registered-by: principal,
        registered-at: uint,
        status: (string-ascii 20),
        data-entries: uint
    }
)

(define-map patient-data
    uint
    {
        patient-id: uint,
        data-type: (string-ascii 30),
        data-hash: (buff 32),
        recorded-by: principal,
        recorded-at: uint,
        verified: bool,
        verified-by: (optional principal)
    }
)

(define-map data-verification
    uint
    {
        data-id: uint,
        verifier: principal,
        verified-at: uint,
        verification-hash: (buff 32),
        notes: (string-ascii 200)
    }
)

(define-map reward-pools
    uint
    {
        trial-id: uint,
        total-amount: uint,
        remaining-amount: uint,
        enrollment-reward: uint,
        data-submission-reward: uint,
        verification-reward: uint,
        created-by: principal,
        created-at: uint,
        active: bool
    }
)

(define-map participant-rewards
    { trial-id: uint, participant: principal }
    {
        enrollment-claimed: bool,
        data-submissions: uint,
        data-rewards-claimed: uint,
        total-earned: uint
    }
)

(define-map verifier-rewards
    { trial-id: uint, verifier: principal }
    {
        verifications-completed: uint,
        rewards-claimed: uint,
        total-earned: uint
    }
)

(define-map multi-sig-configs
    { trial-id: uint }
    {
        threshold: uint,
        max-approvers: uint,
        active: bool
    }
)

(define-map trial-approvers
    { trial-id: uint, approver: principal }
    {
        active: bool,
        added-at: uint
    }
)

(define-map approver-counts
    { trial-id: uint }
    {
        count: uint
    }
)

(define-map data-signatures
    { data-id: uint, approver: principal }
    {
        signed-at: uint
    }
)

(define-map signature-counts
    { data-id: uint }
    {
        count: uint
    }
)

(define-read-only (get-trial (trial-id uint))
    (map-get? trials trial-id)
)

(define-read-only (get-patient (patient-id uint))
    (map-get? patients patient-id)
)

(define-read-only (get-patient-data (data-id uint))
    (map-get? patient-data data-id)
)

(define-read-only (get-trial-permission (trial-id uint) (user principal))
    (map-get? trial-permissions { trial-id: trial-id, user: user })
)

(define-read-only (get-data-verification (data-id uint))
    (map-get? data-verification data-id)
)

(define-read-only (get-current-trial-id)
    (var-get next-trial-id)
)

(define-read-only (get-current-patient-id)
    (var-get next-patient-id)
)

(define-read-only (get-current-data-entry-id)
    (var-get next-data-entry-id)
)

(define-read-only (get-reward-pool (pool-id uint))
    (map-get? reward-pools pool-id)
)

(define-read-only (get-participant-rewards (trial-id uint) (participant principal))
    (map-get? participant-rewards { trial-id: trial-id, participant: participant })
)

(define-read-only (get-verifier-rewards (trial-id uint) (verifier principal))
    (map-get? verifier-rewards { trial-id: trial-id, verifier: verifier })
)

(define-private (is-authorized (trial-id uint) (user principal))
    (or
        (is-eq user contract-owner)
        (is-some (map-get? trial-permissions { trial-id: trial-id, user: user }))
    )
)

(define-private (is-trial-active (trial-id uint))
    (match (map-get? trials trial-id)
        trial (is-eq (get status trial) "active")
        false
    )
)

(define-public (create-trial
    (title (string-ascii 100))
    (institution (string-ascii 100))
    (duration-blocks uint)
)
    (let
        (
            (trial-id (var-get next-trial-id))
            (current-block stacks-block-height)
        )
        (asserts! (> (len title) u0) err-invalid-data)
        (asserts! (> (len institution) u0) err-invalid-data)
        (asserts! (> duration-blocks u0) err-invalid-data)

        (map-set trials trial-id
            {
                title: title,
                principal-investigator: tx-sender,
                institution: institution,
                start-block: current-block,
                end-block: (+ current-block duration-blocks),
                status: "active",
                patient-count: u0,
                data-entries: u0
            }
        )

        (map-set trial-permissions
            { trial-id: trial-id, user: tx-sender }
            { role: "admin", granted-at: current-block }
        )

        (var-set next-trial-id (+ trial-id u1))
        (ok trial-id)
    )
)

(define-public (grant-permission
    (trial-id uint)
    (user principal)
    (role (string-ascii 20))
)
    (let
        (
            (trial (unwrap! (map-get? trials trial-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get principal-investigator trial)) err-unauthorized)
        (asserts! (or (is-eq role "researcher") (is-eq role "admin")) err-invalid-data)

        (map-set trial-permissions
            { trial-id: trial-id, user: user }
            { role: role, granted-at: stacks-block-height }
        )
        (ok true)
    )
)

(define-public (register-patient
    (trial-id uint)
    (patient-identifier (string-ascii 50))
)
    (let
        (
            (patient-id (var-get next-patient-id))
            (trial (unwrap! (map-get? trials trial-id) err-not-found))
        )
        (asserts! (is-authorized trial-id tx-sender) err-unauthorized)
        (asserts! (is-trial-active trial-id) err-trial-not-active)
        (asserts! (> (len patient-identifier) u0) err-invalid-data)

        (map-set patients patient-id
            {
                trial-id: trial-id,
                patient-identifier: patient-identifier,
                registered-by: tx-sender,
                registered-at: stacks-block-height,
                status: "enrolled",
                data-entries: u0
            }
        )

        (map-set participant-rewards
            { trial-id: trial-id, participant: tx-sender }
            (merge (default-to
                { enrollment-claimed: false, data-submissions: u0, data-rewards-claimed: u0, total-earned: u0 }
                (map-get? participant-rewards { trial-id: trial-id, participant: tx-sender })
            ) { data-submissions: u0 })
        )

        (map-set trials trial-id
            (merge trial { patient-count: (+ (get patient-count trial) u1) })
        )

        (var-set next-patient-id (+ patient-id u1))
        (ok patient-id)
    )
)

(define-public (record-patient-data
    (patient-id uint)
    (data-type (string-ascii 30))
    (data-hash (buff 32))
)
    (let
        (
            (data-id (var-get next-data-entry-id))
            (patient (unwrap! (map-get? patients patient-id) err-not-found))
            (trial (unwrap! (map-get? trials (get trial-id patient)) err-not-found))
        )
        (asserts! (is-authorized (get trial-id patient) tx-sender) err-unauthorized)
        (asserts! (is-trial-active (get trial-id patient)) err-trial-not-active)
        (asserts! (> (len data-type) u0) err-invalid-data)
        (asserts! (> (len data-hash) u0) err-invalid-data)

        (map-set patient-data data-id
            {
                patient-id: patient-id,
                data-type: data-type,
                data-hash: data-hash,
                recorded-by: tx-sender,
                recorded-at: stacks-block-height,
                verified: false,
                verified-by: none
            }
        )

        (map-set patients patient-id
            (merge patient { data-entries: (+ (get data-entries patient) u1) })
        )

        (map-set trials (get trial-id patient)
            (merge trial { data-entries: (+ (get data-entries trial) u1) })
        )

        (let
            (
                (current-rewards (default-to
                    { enrollment-claimed: false, data-submissions: u0, data-rewards-claimed: u0, total-earned: u0 }
                    (map-get? participant-rewards { trial-id: (get trial-id patient), participant: tx-sender })
                ))
            )
            (map-set participant-rewards
                { trial-id: (get trial-id patient), participant: tx-sender }
                (merge current-rewards { data-submissions: (+ (get data-submissions current-rewards) u1) })
            )
        )

        (var-set next-data-entry-id (+ data-id u1))
        (ok data-id)
    )
)

(define-public (verify-data
    (data-id uint)
    (verification-hash (buff 32))
    (notes (string-ascii 200))
)
    (let
        (
            (data-entry (unwrap! (map-get? patient-data data-id) err-not-found))
            (patient (unwrap! (map-get? patients (get patient-id data-entry)) err-not-found))
            (config (map-get? multi-sig-configs { trial-id: (get trial-id patient) }))
        )
        (asserts! (is-authorized (get trial-id patient) tx-sender) err-unauthorized)
        (asserts! (not (get verified data-entry)) err-invalid-data)
        (asserts! (> (len verification-hash) u0) err-invalid-data)
        (if (and (is-some config) (get active (unwrap-panic config)))
            err-multi-sig-required
            (begin
                (map-set patient-data data-id
                    (merge data-entry
                        {
                            verified: true,
                            verified-by: (some tx-sender)
                        }
                    )
                )
                (map-set data-verification data-id
                    {
                        data-id: data-id,
                        verifier: tx-sender,
                        verified-at: stacks-block-height,
                        verification-hash: verification-hash,
                        notes: notes
                    }
                )
                (let
                    (
                        (current-verifier-rewards (default-to
                            { verifications-completed: u0, rewards-claimed: u0, total-earned: u0 }
                            (map-get? verifier-rewards { trial-id: (get trial-id patient), verifier: tx-sender })
                        ))
                    )
                    (map-set verifier-rewards
                        { trial-id: (get trial-id patient), verifier: tx-sender }
                        (merge current-verifier-rewards { verifications-completed: (+ (get verifications-completed current-verifier-rewards) u1) })
                    )
                )
                (ok true)
            )
        )
    )
)

(define-public (update-trial-status
    (trial-id uint)
    (new-status (string-ascii 20))
)
    (let
        (
            (trial (unwrap! (map-get? trials trial-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get principal-investigator trial)) err-unauthorized)
        (asserts! (or
            (is-eq new-status "active")
            (is-eq new-status "paused")
            (is-eq new-status "completed")
            (is-eq new-status "terminated")
        ) err-invalid-status)

        (map-set trials trial-id
            (merge trial { status: new-status })
        )
        (ok true)
    )
)

(define-public (update-patient-status
    (patient-id uint)
    (new-status (string-ascii 20))
)
    (let
        (
            (patient (unwrap! (map-get? patients patient-id) err-not-found))
        )
        (asserts! (is-authorized (get trial-id patient) tx-sender) err-unauthorized)
        (asserts! (or
            (is-eq new-status "enrolled")
            (is-eq new-status "active")
            (is-eq new-status "completed")
            (is-eq new-status "withdrawn")
        ) err-invalid-status)

        (map-set patients patient-id
            (merge patient { status: new-status })
        )
        (ok true)
    )
)

(define-read-only (get-trial-stats (trial-id uint))
    (match (map-get? trials trial-id)
        trial (ok {
            patient-count: (get patient-count trial),
            data-entries: (get data-entries trial),
            status: (get status trial),
            blocks-remaining: (if (> (get end-block trial) stacks-block-height)
                (- (get end-block trial) stacks-block-height)
                u0
            )
        })
        err-not-found
    )
)

(define-read-only (get-patient-summary (patient-id uint))
    (match (map-get? patients patient-id)
        patient (ok {
            trial-id: (get trial-id patient),
            status: (get status patient),
            data-entries: (get data-entries patient),
            registered-at: (get registered-at patient)
        })
        err-not-found
    )
)

(define-read-only (verify-data-integrity (data-id uint) (expected-hash (buff 32)))
    (match (map-get? patient-data data-id)
        data-entry (ok (is-eq (get data-hash data-entry) expected-hash))
        err-not-found
    )
)

(define-read-only (get-verification-count (trial-id uint))
    (match (map-get? trials trial-id)
        trial (ok (fold count-verified-entries (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) u0))
        err-not-found
    )
)

(define-private (count-verified-entries (data-id uint) (acc uint))
    (match (map-get? patient-data data-id)
        data-entry (if (get verified data-entry) (+ acc u1) acc)
        acc
    )
)

(define-public (bulk-verify-data
    (data-ids (list 10 uint))
    (verification-hash (buff 32))
    (notes (string-ascii 200))
)
    (let
        (
            (first-data-id (unwrap! (element-at? data-ids u0) err-invalid-data))
        )
        (asserts! (> (len data-ids) u0) err-invalid-data)
        (verify-data first-data-id verification-hash notes)
    )
)

(define-read-only (get-audit-trail (trial-id uint))
    (let
        (
            (trial (unwrap! (map-get? trials trial-id) err-not-found))
        )
        (ok {
            created-at: (get start-block trial),
            created-by: (get principal-investigator trial),
            current-status: (get status trial),
            patient-count: (get patient-count trial),
            total-data-entries: (get data-entries trial)
        })
    )
)

(define-public (emergency-pause-trial (trial-id uint))
    (let
        (
            (trial (unwrap! (map-get? trials trial-id) err-not-found))
        )
        (asserts! (or
            (is-eq tx-sender contract-owner)
            (is-eq tx-sender (get principal-investigator trial))
        ) err-unauthorized)

        (map-set trials trial-id
            (merge trial { status: "paused" })
        )
        (ok true)
    )
)

(define-read-only (get-trial-timeline (trial-id uint))
    (match (map-get? trials trial-id)
        trial (ok {
            start-block: (get start-block trial),
            end-block: (get end-block trial),
            current-block: stacks-block-height,
            progress-percentage: (/ (* (- stacks-block-height (get start-block trial)) u100)
                                   (- (get end-block trial) (get start-block trial)))
        })
        err-not-found
    )
)

(define-public (extend-trial-duration (trial-id uint) (additional-blocks uint))
    (let
        (
            (trial (unwrap! (map-get? trials trial-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get principal-investigator trial)) err-unauthorized)
        (asserts! (> additional-blocks u0) err-invalid-data)

        (map-set trials trial-id
            (merge trial { end-block: (+ (get end-block trial) additional-blocks) })
        )
        (ok true)
    )
)

(define-read-only (get-unverified-data (trial-id uint))
    (match (map-get? trials trial-id)
        trial (ok (fold collect-unverified (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) (list)))
        err-not-found
    )
)

(define-private (collect-unverified (data-id uint) (acc (list 10 uint)))
    (match (map-get? patient-data data-id)
        data-entry (if (not (get verified data-entry))
                      (unwrap-panic (as-max-len? (append acc data-id) u10))
                      acc)
        acc
    )
)

(define-public (batch-register-patients
    (trial-id uint)
    (patient-identifiers (list 5 (string-ascii 50)))
)
    (let
        (
            (first-identifier (unwrap! (element-at? patient-identifiers u0) err-invalid-data))
        )
        (asserts! (is-authorized trial-id tx-sender) err-unauthorized)
        (asserts! (is-trial-active trial-id) err-trial-not-active)
        (asserts! (> (len patient-identifiers) u0) err-invalid-data)
        (register-patient trial-id first-identifier)
    )
)

(define-read-only (validate-data-consistency (trial-id uint))
    (let
        (
            (trial (unwrap! (map-get? trials trial-id) err-not-found))
        )
        (ok {
            trial-exists: true,
            patients-registered: (get patient-count trial),
            data-entries-recorded: (get data-entries trial),
            trial-active: (is-trial-active trial-id)
        })
    )
)

(define-public (finalize-trial (trial-id uint))
    (let
        (
            (trial (unwrap! (map-get? trials trial-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get principal-investigator trial)) err-unauthorized)
        (asserts! (>= stacks-block-height (get end-block trial)) err-invalid-data)

        (map-set trials trial-id
            (merge trial { status: "completed" })
        )
        (ok true)
    )
)

(define-read-only (get-contract-info)
    (ok {
        total-trials: (- (var-get next-trial-id) u1),
        total-patients: (- (var-get next-patient-id) u1),
        total-data-entries: (- (var-get next-data-entry-id) u1),
        total-reward-pools: (- (var-get next-reward-pool-id) u1),
        contract-owner: contract-owner
    })
)

(define-public (create-reward-pool
    (trial-id uint)
    (enrollment-reward uint)
    (data-submission-reward uint)
    (verification-reward uint)
)
    (let
        (
            (pool-id (var-get next-reward-pool-id))
            (trial (unwrap! (map-get? trials trial-id) err-not-found))
            (total-amount (+ enrollment-reward (+ data-submission-reward verification-reward)))
        )
        (asserts! (is-eq tx-sender (get principal-investigator trial)) err-unauthorized)
        (asserts! (> total-amount u0) err-invalid-data)

        (try! (stx-transfer? total-amount tx-sender (as-contract tx-sender)))

        (map-set reward-pools pool-id
            {
                trial-id: trial-id,
                total-amount: total-amount,
                remaining-amount: total-amount,
                enrollment-reward: enrollment-reward,
                data-submission-reward: data-submission-reward,
                verification-reward: verification-reward,
                created-by: tx-sender,
                created-at: stacks-block-height,
                active: true
            }
        )

        (var-set next-reward-pool-id (+ pool-id u1))
        (ok pool-id)
    )
)

(define-public (fund-reward-pool (pool-id uint) (additional-amount uint))
    (let
        (
            (pool (unwrap! (map-get? reward-pools pool-id) err-not-found))
            (trial (unwrap! (map-get? trials (get trial-id pool)) err-not-found))
        )
        (asserts! (is-eq tx-sender (get principal-investigator trial)) err-unauthorized)
        (asserts! (get active pool) err-invalid-data)
        (asserts! (> additional-amount u0) err-invalid-data)

        (try! (stx-transfer? additional-amount tx-sender (as-contract tx-sender)))

        (map-set reward-pools pool-id
            (merge pool
                {
                    total-amount: (+ (get total-amount pool) additional-amount),
                    remaining-amount: (+ (get remaining-amount pool) additional-amount)
                }
            )
        )
        (ok true)
    )
)

(define-public (claim-enrollment-reward (trial-id uint))
    (let
        (
            (pool (unwrap! (get-trial-reward-pool trial-id) err-not-found))
            (existing-rewards (default-to
                { enrollment-claimed: false, data-submissions: u0, data-rewards-claimed: u0, total-earned: u0 }
                (map-get? participant-rewards { trial-id: trial-id, participant: tx-sender })
            ))
        )
        (asserts! (get active pool) err-invalid-data)
        (asserts! (not (get enrollment-claimed existing-rewards)) err-reward-already-claimed)
        (asserts! (is-patient-in-trial trial-id tx-sender) err-unauthorized)
        (asserts! (>= (get remaining-amount pool) (get enrollment-reward pool)) err-insufficient-funds)

        (try! (as-contract (stx-transfer? (get enrollment-reward pool) tx-sender (get created-by pool))))

        (let
            (
                (pool-id (unwrap! (get-pool-id-by-trial trial-id) err-not-found))
            )
            (map-set reward-pools pool-id
                (merge pool { remaining-amount: (- (get remaining-amount pool) (get enrollment-reward pool)) })
            )
        )

        (map-set participant-rewards
            { trial-id: trial-id, participant: tx-sender }
            (merge existing-rewards
                {
                    enrollment-claimed: true,
                    total-earned: (+ (get total-earned existing-rewards) (get enrollment-reward pool))
                }
            )
        )
        (ok true)
    )
)

(define-public (claim-data-submission-reward (trial-id uint))
    (let
        (
            (pool (unwrap! (get-trial-reward-pool trial-id) err-not-found))
            (existing-rewards (default-to
                { enrollment-claimed: false, data-submissions: u0, data-rewards-claimed: u0, total-earned: u0 }
                (map-get? participant-rewards { trial-id: trial-id, participant: tx-sender })
            ))
            (unclaimed-submissions (- (get data-submissions existing-rewards) (get data-rewards-claimed existing-rewards)))
            (reward-amount (* unclaimed-submissions (get data-submission-reward pool)))
        )
        (asserts! (get active pool) err-invalid-data)
        (asserts! (> unclaimed-submissions u0) err-no-rewards-available)
        (asserts! (>= (get remaining-amount pool) reward-amount) err-insufficient-funds)

        (try! (as-contract (stx-transfer? reward-amount tx-sender (get created-by pool))))

        (let
            (
                (pool-id (unwrap! (get-pool-id-by-trial trial-id) err-not-found))
            )
            (map-set reward-pools pool-id
                (merge pool { remaining-amount: (- (get remaining-amount pool) reward-amount) })
            )
        )

        (map-set participant-rewards
            { trial-id: trial-id, participant: tx-sender }
            (merge existing-rewards
                {
                    data-rewards-claimed: (get data-submissions existing-rewards),
                    total-earned: (+ (get total-earned existing-rewards) reward-amount)
                }
            )
        )
        (ok true)
    )
)

(define-public (claim-verification-reward (trial-id uint))
    (let
        (
            (pool (unwrap! (get-trial-reward-pool trial-id) err-not-found))
            (existing-rewards (default-to
                { verifications-completed: u0, rewards-claimed: u0, total-earned: u0 }
                (map-get? verifier-rewards { trial-id: trial-id, verifier: tx-sender })
            ))
            (unclaimed-verifications (- (get verifications-completed existing-rewards) (get rewards-claimed existing-rewards)))
            (reward-amount (* unclaimed-verifications (get verification-reward pool)))
        )
        (asserts! (get active pool) err-invalid-data)
        (asserts! (> unclaimed-verifications u0) err-no-rewards-available)
        (asserts! (>= (get remaining-amount pool) reward-amount) err-insufficient-funds)

        (try! (as-contract (stx-transfer? reward-amount tx-sender (get created-by pool))))

        (let
            (
                (pool-id (unwrap! (get-pool-id-by-trial trial-id) err-not-found))
            )
            (map-set reward-pools pool-id
                (merge pool { remaining-amount: (- (get remaining-amount pool) reward-amount) })
            )
        )

        (map-set verifier-rewards
            { trial-id: trial-id, verifier: tx-sender }
            (merge existing-rewards
                {
                    rewards-claimed: (get verifications-completed existing-rewards),
                    total-earned: (+ (get total-earned existing-rewards) reward-amount)
                }
            )
        )
        (ok true)
    )
)

(define-public (deactivate-reward-pool (pool-id uint))
    (let
        (
            (pool (unwrap! (map-get? reward-pools pool-id) err-not-found))
            (trial (unwrap! (map-get? trials (get trial-id pool)) err-not-found))
        )
        (asserts! (is-eq tx-sender (get principal-investigator trial)) err-unauthorized)
        (asserts! (get active pool) err-invalid-data)

        (try! (as-contract (stx-transfer? (get remaining-amount pool) tx-sender (get created-by pool))))

        (map-set reward-pools pool-id
            (merge pool { active: false, remaining-amount: u0 })
        )
        (ok true)
    )
)

(define-private (get-trial-reward-pool (trial-id uint))
    (match (get-pool-id-by-trial trial-id)
        pool-id (map-get? reward-pools pool-id)
        none
    )
)

(define-private (get-pool-id-by-trial (target-trial-id uint))
    (get result (fold check-pool-match (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)
          { target: target-trial-id, result: none }))
)

(define-private (check-pool-match
    (pool-id uint)
    (state { target: uint, result: (optional uint) })
)
    (match (get result state)
        found-id state
        (match (map-get? reward-pools pool-id)
            pool (if (is-eq (get trial-id pool) (get target state))
                    (merge state { result: (some pool-id) })
                    state)
            state
        )
    )
)

(define-private (is-patient-in-trial (trial-id uint) (user principal))
    (is-some (fold check-patient-in-trial (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) none))
)

(define-private (check-patient-in-trial (patient-id uint) (acc (optional bool)))
    (match acc
        found (some found)
        (match (map-get? patients patient-id)
            patient (if (is-eq (get registered-by patient) tx-sender)
                        (some true)
                        none)
            none
        )
    )
)

(define-read-only (get-reward-pool-stats (trial-id uint))
    (match (get-trial-reward-pool trial-id)
        pool (ok {
            total-amount: (get total-amount pool),
            remaining-amount: (get remaining-amount pool),
            enrollment-reward: (get enrollment-reward pool),
            data-submission-reward: (get data-submission-reward pool),
            verification-reward: (get verification-reward pool),
            active: (get active pool)
        })
        err-not-found
    )
)

(define-read-only (calculate-available-rewards (trial-id uint) (user principal))
    (let
        (
            (pool (unwrap! (get-trial-reward-pool trial-id) err-not-found))
            (participant-reward-data (default-to
                { enrollment-claimed: false, data-submissions: u0, data-rewards-claimed: u0, total-earned: u0 }
                (map-get? participant-rewards { trial-id: trial-id, participant: user })
            ))
            (verifier-reward-data (default-to
                { verifications-completed: u0, rewards-claimed: u0, total-earned: u0 }
                (map-get? verifier-rewards { trial-id: trial-id, verifier: user })
            ))
        )
        (ok {
            enrollment-available: (if (get enrollment-claimed participant-reward-data) u0 (get enrollment-reward pool)),
            data-rewards-available: (*
                (- (get data-submissions participant-reward-data) (get data-rewards-claimed participant-reward-data))
                (get data-submission-reward pool)
            ),
            verification-rewards-available: (*
                (- (get verifications-completed verifier-reward-data) (get rewards-claimed verifier-reward-data))
                (get verification-reward pool)
            )
        })
    )
)

(define-public (configure-multi-sig (trial-id uint) (threshold uint) (max-approvers uint))
    (let
        (
            (trial (unwrap! (map-get? trials trial-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get principal-investigator trial)) err-unauthorized)
        (asserts! (> threshold u0) err-invalid-threshold)
        (asserts! (> max-approvers u0) err-invalid-data)
        (asserts! (<= threshold max-approvers) err-invalid-threshold)
        (map-set multi-sig-configs { trial-id: trial-id } { threshold: threshold, max-approvers: max-approvers, active: true })
        (map-set approver-counts { trial-id: trial-id } { count: u0 })
        (ok true)
    )
)

(define-public (add-approver (trial-id uint) (approver principal))
    (let
        (
            (trial (unwrap! (map-get? trials trial-id) err-not-found))
            (config (unwrap! (map-get? multi-sig-configs { trial-id: trial-id }) err-not-found))
            (count-row (default-to { count: u0 } (map-get? approver-counts { trial-id: trial-id })))
        )
        (asserts! (is-eq tx-sender (get principal-investigator trial)) err-unauthorized)
        (asserts! (get active config) err-invalid-data)
        (asserts! (< (get count count-row) (get max-approvers config)) err-invalid-data)
        (map-set trial-approvers { trial-id: trial-id, approver: approver } { active: true, added-at: stacks-block-height })
        (map-set approver-counts { trial-id: trial-id } { count: (+ (get count count-row) u1) })
        (ok true)
    )
)

(define-public (remove-approver (trial-id uint) (approver principal))
    (let
        (
            (trial (unwrap! (map-get? trials trial-id) err-not-found))
            (config (unwrap! (map-get? multi-sig-configs { trial-id: trial-id }) err-not-found))
            (count-row (default-to { count: u0 } (map-get? approver-counts { trial-id: trial-id })))
            (existing (map-get? trial-approvers { trial-id: trial-id, approver: approver }))
        )
        (asserts! (is-eq tx-sender (get principal-investigator trial)) err-unauthorized)
        (asserts! (get active config) err-invalid-data)
        (if (is-some existing)
            (begin
                (map-set trial-approvers { trial-id: trial-id, approver: approver } { active: false, added-at: (get added-at (unwrap-panic existing)) })
                (map-set approver-counts { trial-id: trial-id } { count: (if (> (get count count-row) u0) (- (get count count-row) u1) u0) })
                (ok true)
            )
            (ok false)
        )
    )
)

(define-public (submit-multi-sig-approval (data-id uint) (verification-hash (buff 32)) (notes (string-ascii 200)))
    (let
        (
            (data-entry (unwrap! (map-get? patient-data data-id) err-not-found))
            (patient (unwrap! (map-get? patients (get patient-id data-entry)) err-not-found))
            (trial-id (get trial-id patient))
            (config (unwrap! (map-get? multi-sig-configs { trial-id: trial-id }) err-multi-sig-required))
            (approver (map-get? trial-approvers { trial-id: trial-id, approver: tx-sender }))
            (count-row (default-to { count: u0 } (map-get? signature-counts { data-id: data-id })))
            (already (map-get? data-signatures { data-id: data-id, approver: tx-sender }))
        )
        (asserts! (get active config) err-invalid-data)
        (asserts! (is-some approver) err-not-approver)
        (asserts! (get active (unwrap-panic approver)) err-not-approver)
        (asserts! (not (get verified data-entry)) err-invalid-data)
        (asserts! (> (len verification-hash) u0) err-invalid-data)
        (asserts! (is-none already) err-approver-already-signed)
        (map-set data-signatures { data-id: data-id, approver: tx-sender } { signed-at: stacks-block-height })
        (map-set signature-counts { data-id: data-id } { count: (+ (get count count-row) u1) })
        (let ((new-count (+ (get count count-row) u1)))
            (if (>= new-count (get threshold config))
                (begin
                    (map-set patient-data data-id (merge data-entry { verified: true, verified-by: (some tx-sender) }))
                    (map-set data-verification data-id { data-id: data-id, verifier: tx-sender, verified-at: stacks-block-height, verification-hash: verification-hash, notes: notes })
                    (let ((current-verifier-rewards (default-to { verifications-completed: u0, rewards-claimed: u0, total-earned: u0 } (map-get? verifier-rewards { trial-id: trial-id, verifier: tx-sender }))))
                        (map-set verifier-rewards { trial-id: trial-id, verifier: tx-sender } (merge current-verifier-rewards { verifications-completed: (+ (get verifications-completed current-verifier-rewards) u1) }))
                    )
                    (ok new-count)
                )
                (begin
                    (let ((current-verifier-rewards (default-to { verifications-completed: u0, rewards-claimed: u0, total-earned: u0 } (map-get? verifier-rewards { trial-id: trial-id, verifier: tx-sender }))))
                        (map-set verifier-rewards { trial-id: trial-id, verifier: tx-sender } (merge current-verifier-rewards { verifications-completed: (+ (get verifications-completed current-verifier-rewards) u1) }))
                    )
                    (ok new-count)
                )
            )
        )
    )
)

(define-read-only (get-multi-sig-config (trial-id uint))
    (map-get? multi-sig-configs { trial-id: trial-id })
)

(define-read-only (get-signature-count (data-id uint))
    (get count (default-to { count: u0 } (map-get? signature-counts { data-id: data-id })))
)

(define-read-only (has-approver-signed (data-id uint) (approver principal))
    (is-some (map-get? data-signatures { data-id: data-id, approver: approver }))
)

(define-read-only (is-multi-sig-verified (data-id uint))
    (match (map-get? patient-data data-id)
        data-entry (let
            (
                (patient (unwrap! (map-get? patients (get patient-id data-entry)) err-not-found))
                (config (map-get? multi-sig-configs { trial-id: (get trial-id patient) }))
                (count-row (default-to { count: u0 } (map-get? signature-counts { data-id: data-id })))
            )
            (if (and (is-some config) (get active (unwrap-panic config)))
                (ok (>= (get count count-row) (get threshold (unwrap-panic config))))
                (ok (get verified data-entry))
            )
        )
        err-not-found
    )
)

(define-read-only (get-pending-approvals (trial-id uint))
    (get result (fold collect-pending (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) { target: trial-id, result: (list) }))
)

(define-private (collect-pending (data-id uint) (state { target: uint, result: (list 10 uint) }))
    (match (map-get? patient-data data-id)
        data-entry (let
            (
                (patient-opt (map-get? patients (get patient-id data-entry)))
                (config-opt (map-get? multi-sig-configs { trial-id: (get target state) }))
                (count-row (default-to { count: u0 } (map-get? signature-counts { data-id: data-id })))
            )
            (if (and (is-some patient-opt)
                     (is-some config-opt)
                     (get active (unwrap-panic config-opt))
                     (is-eq (get trial-id (unwrap-panic patient-opt)) (get target state))
                     (not (get verified data-entry))
                     (< (get count count-row) (get threshold (unwrap-panic config-opt))))
                (merge state { result: (unwrap-panic (as-max-len? (append (get result state) data-id) u10)) })
                state
            )
        )
        state
    )
)

(define-public (configure-audit-checkpoint (trial-id uint) (interval-blocks uint) (verification-threshold uint))
    (let
        (
            (trial (unwrap! (map-get? trials trial-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get principal-investigator trial)) err-unauthorized)
        (asserts! (> interval-blocks u0) err-invalid-data)
        (asserts! (<= verification-threshold u100) err-invalid-data)
        (map-set checkpoint-configs
            { trial-id: trial-id }
            {
                interval-blocks: interval-blocks,
                verification-threshold: verification-threshold
            }
        )
        (ok true)
    )
)

(define-public (create-audit-checkpoint (trial-id uint))
    (let
        (
            (trial (unwrap! (map-get? trials trial-id) err-not-found))
            (config (unwrap! (map-get? checkpoint-configs { trial-id: trial-id }) err-not-found))
            (checkpoint-id (var-get next-checkpoint-id))
            (verified-count (get data-entries trial))
            (total-count (get data-entries trial))
            (verification-rate (if (is-eq total-count u0) u100 (/ (* verified-count u100) total-count)))
            (passed (>= verification-rate (get verification-threshold config)))
        )
        (map-set audit-checkpoints
            { checkpoint-id: checkpoint-id }
            {
                trial-id: trial-id,
                block-created: stacks-block-height,
                verified-count: verified-count,
                total-count: total-count,
                passed: passed,
                verifier: tx-sender
            }
        )
        (var-set next-checkpoint-id (+ checkpoint-id u1))
        (ok checkpoint-id)
    )
)

(define-public (skip-audit-checkpoint (trial-id uint))
    (let
        (
            (trial (unwrap! (map-get? trials trial-id) err-not-found))
            (checkpoint-id (var-get next-checkpoint-id))
        )
        (asserts! (is-eq tx-sender (get principal-investigator trial)) err-unauthorized)
        (map-set audit-checkpoints
            { checkpoint-id: checkpoint-id }
            {
                trial-id: trial-id,
                block-created: stacks-block-height,
                verified-count: u0,
                total-count: u0,
                passed: true,
                verifier: tx-sender
            }
        )
        (var-set next-checkpoint-id (+ checkpoint-id u1))
        (ok checkpoint-id)
    )
)

(define-read-only (get-checkpoint-config (trial-id uint))
    (map-get? checkpoint-configs { trial-id: trial-id })
)

(define-read-only (get-audit-checkpoint (checkpoint-id uint))
    (map-get? audit-checkpoints { checkpoint-id: checkpoint-id })
)

(define-read-only (get-trial-compliance-status (trial-id uint))
    (let
        (
            (config (map-get? checkpoint-configs { trial-id: trial-id }))
            (current-id (var-get next-checkpoint-id))
        )
        (if (is-some config)
            (let
                (
                    (last-checkpoint (if (> current-id u0) (map-get? audit-checkpoints { checkpoint-id: (- current-id u1) }) none))
                )
                (ok {
                    config: config,
                    last-checkpoint: last-checkpoint,
                    next-audit-block: (if (is-some last-checkpoint)
                        (some (+ (get block-created (unwrap-panic last-checkpoint)) (get interval-blocks (unwrap-panic config))))
                        none
                    )
                })
            )
            (err u101)
        )
    )
)

(define-read-only (is-trial-compliant (trial-id uint))
    (let
        (
            (current-id (var-get next-checkpoint-id))
        )
        (if (> current-id u0)
            (let
                (
                    (last-checkpoint (map-get? audit-checkpoints { checkpoint-id: (- current-id u1) }))
                )
                (if (is-some last-checkpoint)
                    (if (is-eq trial-id (get trial-id (unwrap-panic last-checkpoint)))
                        (ok (get passed (unwrap-panic last-checkpoint)))
                        (ok true)
                    )
                    (ok true)
                )
            )
            (ok true)
        )
    )
)
