;; Flow Forge - Workflow Automation Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-workflow-not-found (err u101))
(define-constant err-invalid-state (err u102))
(define-constant err-unauthorized (err u103))

;; Data vars
(define-map workflows
    { workflow-id: uint }
    {
        name: (string-ascii 64),
        creator: principal,
        current-state: (string-ascii 24),
        created-at: uint
    }
)

(define-map workflow-states
    { workflow-id: uint, state: (string-ascii 24) }
    {
        allowed-transitions: (list 10 (string-ascii 24)),
        approvers: (list 10 principal)
    }
)

(define-map workflow-history
    { workflow-id: uint, sequence: uint }
    {
        from-state: (string-ascii 24),
        to-state: (string-ascii 24),
        approved-by: principal,
        timestamp: uint
    }
)

;; Data vars for sequence tracking
(define-data-var workflow-id-nonce uint u0)
(define-data-var history-nonce uint u0)

;; Create new workflow
(define-public (create-workflow (name (string-ascii 64)) (initial-state (string-ascii 24)))
    (let
        (
            (new-id (+ (var-get workflow-id-nonce) u1))
        )
        (try! (validate-caller))
        (map-set workflows
            { workflow-id: new-id }
            {
                name: name,
                creator: tx-sender,
                current-state: initial-state,
                created-at: block-height
            }
        )
        (var-set workflow-id-nonce new-id)
        (ok new-id)
    )
)

;; Define workflow state transitions
(define-public (define-state-transitions 
    (workflow-id uint)
    (state (string-ascii 24))
    (transitions (list 10 (string-ascii 24)))
    (approvers (list 10 principal))
)
    (begin
        (try! (validate-caller))
        (map-set workflow-states
            { workflow-id: workflow-id, state: state }
            {
                allowed-transitions: transitions,
                approvers: approvers
            }
        )
        (ok true)
    )
)

;; Transition workflow state
(define-public (transition-workflow
    (workflow-id uint)
    (new-state (string-ascii 24))
)
    (let
        (
            (workflow (unwrap! (get-workflow workflow-id) err-workflow-not-found))
            (current-state (get current-state workflow))
            (state-def (unwrap! (map-get? workflow-states { workflow-id: workflow-id, state: current-state }) err-invalid-state))
            (history-id (+ (var-get history-nonce) u1))
        )
        ;; Validate transition is allowed
        (asserts! (is-valid-transition state-def new-state) err-invalid-state)
        ;; Validate caller is authorized
        (asserts! (is-authorized state-def) err-unauthorized)
        
        ;; Update workflow state
        (map-set workflows
            { workflow-id: workflow-id }
            (merge workflow { current-state: new-state })
        )
        
        ;; Record in history
        (map-set workflow-history
            { workflow-id: workflow-id, sequence: history-id }
            {
                from-state: current-state,
                to-state: new-state,
                approved-by: tx-sender,
                timestamp: block-height
            }
        )
        (var-set history-nonce history-id)
        (ok true)
    )
)

;; Helper functions
(define-private (validate-caller)
    (if (is-eq tx-sender contract-owner)
        (ok true)
        err-owner-only
    )
)

(define-private (get-workflow (workflow-id uint))
    (map-get? workflows { workflow-id: workflow-id })
)

(define-private (is-valid-transition (state-def {allowed-transitions: (list 10 (string-ascii 24)), approvers: (list 10 principal)}) (new-state (string-ascii 24)))
    (is-some (index-of (get allowed-transitions state-def) new-state))
)

(define-private (is-authorized (state-def {allowed-transitions: (list 10 (string-ascii 24)), approvers: (list 10 principal)}))
    (is-some (index-of (get approvers state-def) tx-sender))
)

;; Read only functions
(define-read-only (get-workflow-state (workflow-id uint))
    (get current-state (unwrap! (get-workflow workflow-id) err-workflow-not-found))
)

(define-read-only (get-workflow-history (workflow-id uint) (sequence uint))
    (map-get? workflow-history { workflow-id: workflow-id, sequence: sequence })
)