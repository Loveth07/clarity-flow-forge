;; Flow Forge - Workflow Automation Contract

;; Constants 
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-workflow-not-found (err u101))
(define-constant err-invalid-state (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-template-not-found (err u104))
(define-constant err-invalid-template (err u105))

;; Data vars
(define-map workflows
    { workflow-id: uint }
    {
        name: (string-ascii 64),
        creator: principal,
        current-state: (string-ascii 24),
        created-at: uint,
        template-id: (optional uint)
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

(define-map workflow-templates
    { template-id: uint }
    {
        name: (string-ascii 64),
        creator: principal,
        initial-state: (string-ascii 24),
        states: (list 10 {
            state: (string-ascii 24),
            transitions: (list 10 (string-ascii 24)),
            approvers: (list 10 principal)
        })
    }
)

;; Data vars for sequence tracking
(define-data-var workflow-id-nonce uint u0)
(define-data-var history-nonce uint u0) 
(define-data-var template-id-nonce uint u0)

;; Create workflow template
(define-public (create-template 
    (name (string-ascii 64))
    (initial-state (string-ascii 24))
    (states (list 10 {
        state: (string-ascii 24),
        transitions: (list 10 (string-ascii 24)),
        approvers: (list 10 principal)
    }))
)
    (let
        (
            (new-id (+ (var-get template-id-nonce) u1))
        )
        (try! (validate-caller))
        (map-set workflow-templates
            { template-id: new-id }
            {
                name: name,
                creator: tx-sender,
                initial-state: initial-state,
                states: states
            }
        )
        (var-set template-id-nonce new-id)
        (ok new-id)
    )
)

;; Create workflow from template
(define-public (create-workflow-from-template 
    (name (string-ascii 64))
    (template-id uint)
)
    (let
        (
            (template (unwrap! (map-get? workflow-templates { template-id: template-id }) err-template-not-found))
            (new-id (+ (var-get workflow-id-nonce) u1))
        )
        ;; Create workflow
        (map-set workflows
            { workflow-id: new-id }
            {
                name: name,
                creator: tx-sender,
                current-state: (get initial-state template),
                created-at: block-height,
                template-id: (some template-id)
            }
        )
        
        ;; Setup states from template
        (map define-state-from-template (get states template))
        
        (var-set workflow-id-nonce new-id)
        (ok new-id)
    )
)

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
                created-at: block-height,
                template-id: none
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

(define-private (define-state-from-template (state-def {state: (string-ascii 24), transitions: (list 10 (string-ascii 24)), approvers: (list 10 principal)}))
    (map-set workflow-states
        { workflow-id: (var-get workflow-id-nonce), state: (get state state-def) }
        {
            allowed-transitions: (get transitions state-def),
            approvers: (get approvers state-def)
        }
    )
)

;; Read only functions
(define-read-only (get-workflow-state (workflow-id uint))
    (get current-state (unwrap! (get-workflow workflow-id) err-workflow-not-found))
)

(define-read-only (get-workflow-history (workflow-id uint) (sequence uint))
    (map-get? workflow-history { workflow-id: workflow-id, sequence: sequence })
)

(define-read-only (get-template (template-id uint))
    (map-get? workflow-templates { template-id: template-id })
)
