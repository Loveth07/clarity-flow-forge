;; Flow Forge - Workflow Automation Contract
;; Enhanced version with improved event handling and validation

;; Constants 
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-workflow-not-found (err u101))
(define-constant err-invalid-state (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-template-not-found (err u104))
(define-constant err-invalid-template (err u105))
(define-constant err-invalid-input (err u106))
(define-constant err-circular-transition (err u107))

;; Enhanced Events System
(define-data-var last-event-id uint u0)

(define-map events 
    { event-id: uint }
    {
        event-type: (string-ascii 24),
        category: (string-ascii 24),
        workflow-id: uint,
        data: (string-ascii 256),
        metadata: (optional (string-ascii 256)),
        timestamp: uint
    }
)

;; Event Categories
(define-data-var event-categories (list 10 (string-ascii 24)) 
    (list "WORKFLOW" "TEMPLATE" "STATE_CHANGE" "APPROVAL" "SYSTEM")
)

;; Enhanced template validation and creation
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
        (try! (validate-template-states states initial-state))
        (try! (check-circular-transitions states))
        (try! (validate-approvers states))
        
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
        (emit-event "TEMPLATE_CREATED" "TEMPLATE" new-id (concat "Template: " name) none)
        (ok new-id)
    )
)

;; Enhanced event emission
(define-private (emit-event 
    (event-type (string-ascii 24))
    (category (string-ascii 24))
    (workflow-id uint)
    (data (string-ascii 256))
    (metadata (optional (string-ascii 256)))
)
    (let
        (
            (event-id (+ (var-get last-event-id) u1))
        )
        (map-set events
            { event-id: event-id }
            {
                event-type: event-type,
                category: category,
                workflow-id: workflow-id,
                data: data,
                metadata: metadata,
                timestamp: block-height
            }
        )
        (var-set last-event-id event-id)
        event-id
    )
)

;; New validation helpers
(define-private (check-circular-transitions
    (states (list 10 {
        state: (string-ascii 24),
        transitions: (list 10 (string-ascii 24)),
        approvers: (list 10 principal)
    }))
)
    (ok true) ;; TODO: Implement circular transition detection
)

(define-private (validate-approvers
    (states (list 10 {
        state: (string-ascii 24),
        transitions: (list 10 (string-ascii 24)),
        approvers: (list 10 principal)
    }))
)
    (ok true) ;; TODO: Implement approver validation
)

;; Enhanced query functions
(define-read-only (get-workflow-details-extended (workflow-id uint))
    (let
        (
            (workflow (unwrap! (get-workflow workflow-id) err-workflow-not-found))
            (current-state (get current-state workflow))
            (state-def (map-get? workflow-states { workflow-id: workflow-id, state: current-state }))
            (events (get-workflow-events workflow-id))
        )
        (ok {
            workflow: workflow,
            state-definition: state-def,
            events: events,
            statistics: (get-workflow-statistics workflow-id)
        })
    )
)

(define-read-only (get-workflow-statistics (workflow-id uint))
    (ok {
        total-transitions: (len (get-workflow-events workflow-id)),
        current-state-duration: (- block-height (get last-transition-time workflow-id)),
        approvals-pending: (get-pending-approvals workflow-id)
    })
)
