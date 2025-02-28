;; Flow Forge - Workflow Automation Contract

;; Constants 
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-workflow-not-found (err u101))
(define-constant err-invalid-state (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-template-not-found (err u104))
(define-constant err-invalid-template (err u105))
(define-constant err-invalid-input (err u106))

;; Events
(define-data-var last-event-id uint u0)

(define-map events 
    { event-id: uint }
    {
        event-type: (string-ascii 24),
        workflow-id: uint,
        data: (string-ascii 256),
        timestamp: uint
    }
)

;; Original data maps remain unchanged...
[Previous data map definitions...]

;; Enhanced template creation with validation
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
        (emit-event "TEMPLATE_CREATED" new-id (concat "Template: " name))
        (ok new-id)
    )
)

;; Event emission helper
(define-private (emit-event (event-type (string-ascii 24)) (workflow-id uint) (data (string-ascii 256)))
    (let
        (
            (event-id (+ (var-get last-event-id) u1))
        )
        (map-set events
            { event-id: event-id }
            {
                event-type: event-type,
                workflow-id: workflow-id,
                data: data,
                timestamp: block-height
            }
        )
        (var-set last-event-id event-id)
        event-id
    )
)

;; Enhanced validation helper
(define-private (validate-template-states 
    (states (list 10 {
        state: (string-ascii 24),
        transitions: (list 10 (string-ascii 24)),
        approvers: (list 10 principal)
    }))
    (initial-state (string-ascii 24))
)
    (if (> (len states) u0)
        (if (is-some (find-state states initial-state))
            (ok true)
            err-invalid-input
        )
        err-invalid-input
    )
)

;; New getter functions
(define-read-only (get-workflow-details (workflow-id uint))
    (let
        (
            (workflow (unwrap! (get-workflow workflow-id) err-workflow-not-found))
            (current-state (get current-state workflow))
            (state-def (map-get? workflow-states { workflow-id: workflow-id, state: current-state }))
        )
        (ok {
            workflow: workflow,
            state-definition: state-def
        })
    )
)

(define-read-only (get-workflow-events (workflow-id uint))
    (filter get-events-by-workflow (map-to-list events))
)

;; Previous functions remain unchanged...
[Rest of the original contract functions...]
