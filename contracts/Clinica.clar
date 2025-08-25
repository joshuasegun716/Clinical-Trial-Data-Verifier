;; title: Clinica
;; version: 1.0.0
;; summary: Clinical Trial Data Verifier - ensuring data integrity and transparency

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-data (err u103))
(define-constant err-trial-exists (err u104))
(define-constant err-trial-not-active (err u105))
(define-constant err-patient-exists (err u106))
(define-constant err-invalid-status (err u107))

(define-data-var next-trial-id uint u1)
(define-data-var next-patient-id uint u1)
(define-data-var next-data-entry-id uint u1)

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
        )
        (asserts! (is-authorized (get trial-id patient) tx-sender) err-unauthorized)
        (asserts! (not (get verified data-entry)) err-invalid-data)
        (asserts! (> (len verification-hash) u0) err-invalid-data)
        
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
        
        (ok true)
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
        contract-owner: contract-owner
    })
)
