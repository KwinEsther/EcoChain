;; Constants
(define-constant ECO_TOKEN_RESERVE u1600000)
(define-constant BASE_ACTION_REWARD u14)
(define-constant IMPACT_BONUS u7)
(define-constant MAX_IMPACT_LEVEL u9)
(define-constant ERR_INVALID_ACTION u1)
(define-constant ERR_NO_ECO_TOKENS u2)
(define-constant ERR_RESERVE_EMPTY u3)
(define-constant BLOCKS_PER_ECO_CYCLE u840)
(define-constant SUSTAINABILITY_MULTIPLIER u6)
(define-constant MIN_SUSTAINABILITY_DURATION u672)
(define-constant SUSTAINABILITY_EXIT_FEE u16)

;; Data Variables
(define-data-var total-eco-tokens-generated uint u0)
(define-data-var total-environmental-actions uint u0)
(define-data-var eco-coordinator principal tx-sender)

;; Data Maps
(define-map activist-actions principal uint)
(define-map activist-eco-tokens principal uint)
(define-map action-session-start principal uint)
(define-map activist-impact principal uint)
(define-map activist-last-action principal uint)
(define-map activist-sustainable-tokens principal uint)
(define-map activist-sustainability-start-block principal uint)

;; Public Functions

(define-public (launch-environmental-action (scope uint))
  (let
    (
      (activist tx-sender)
    )
    (asserts! (> scope u0) (err ERR_INVALID_ACTION))
    (map-set action-session-start activist burn-block-height)
    (ok true)
  )
)

(define-public (complete-environmental-action (scope uint))
  (let
    (
      (activist tx-sender)
      (start-block (default-to u0 (map-get? action-session-start activist)))
      (blocks-acting (- burn-block-height start-block))
      (last-action-block (default-to u0 (map-get? activist-last-action activist)))
      (impact-level (default-to u0 (map-get? activist-impact activist)))
      (capped-impact (if (<= impact-level MAX_IMPACT_LEVEL) impact-level MAX_IMPACT_LEVEL))
      (reward-amount (+ BASE_ACTION_REWARD (* capped-impact IMPACT_BONUS)))
    )
    (asserts! (and (> start-block u0) (>= blocks-acting scope)) (err ERR_INVALID_ACTION))
    (map-set activist-actions activist (+ (default-to u0 (map-get? activist-actions activist)) u1))
    (map-set activist-eco-tokens activist (+ (default-to u0 (map-get? activist-eco-tokens activist)) reward-amount))
    (if (< (- burn-block-height last-action-block) BLOCKS_PER_ECO_CYCLE)
      (map-set activist-impact activist (+ impact-level u1))
      (map-set activist-impact activist u1)
    )
    (map-set activist-last-action activist burn-block-height)
    (var-set total-environmental-actions (+ (var-get total-environmental-actions) u1))
    (var-set total-eco-tokens-generated (+ (var-get total-eco-tokens-generated) reward-amount))
    (asserts! (<= (var-get total-eco-tokens-generated) ECO_TOKEN_RESERVE) (err ERR_RESERVE_EMPTY))
    (ok reward-amount)
  )
)

(define-public (claim-eco-rewards)
  (let
    (
      (activist tx-sender)
      (token-balance (default-to u0 (map-get? activist-eco-tokens activist)))
    )
    (asserts! (> token-balance u0) (err ERR_NO_ECO_TOKENS))
    (map-set activist-eco-tokens activist u0)
    (ok token-balance)
  )
)

;; Sustainability Features

(define-public (pledge-sustainable-tokens (amount uint))
  (let
    (
      (activist tx-sender)
    )
    (asserts! (> amount u0) (err ERR_INVALID_ACTION))
    (asserts! (>= (var-get total-eco-tokens-generated) amount) (err ERR_RESERVE_EMPTY))
    (map-set activist-sustainable-tokens activist amount)
    (map-set activist-sustainability-start-block activist burn-block-height)
    (var-set total-eco-tokens-generated (- (var-get total-eco-tokens-generated) amount))
    (ok amount)
  )
)

(define-public (reclaim-sustainable-tokens)
  (let
    (
      (activist tx-sender)
      (sustainable-amount (default-to u0 (map-get? activist-sustainable-tokens activist)))
      (sustainability-start-block (default-to u0 (map-get? activist-sustainability-start-block activist)))
      (blocks-sustainable (- burn-block-height sustainability-start-block))
      (penalty (if (< blocks-sustainable MIN_SUSTAINABILITY_DURATION) (/ (* sustainable-amount SUSTAINABILITY_EXIT_FEE) u100) u0))
      (final-amount (- sustainable-amount penalty))
    )
    (asserts! (> sustainable-amount u0) (err ERR_NO_ECO_TOKENS))
    (map-set activist-sustainable-tokens activist u0)
    (map-set activist-sustainability-start-block activist u0)
    (var-set total-eco-tokens-generated (+ (var-get total-eco-tokens-generated) final-amount))
    (ok final-amount)
  )
)

;; Read-Only Functions

(define-read-only (get-environmental-action-count (user principal))
  (default-to u0 (map-get? activist-actions user))
)

(define-read-only (get-eco-token-balance (user principal))
  (default-to u0 (map-get? activist-eco-tokens user))
)

(define-read-only (get-impact-level (user principal))
  (default-to u0 (map-get? activist-impact user))
)

(define-read-only (get-eco-platform-statistics)
  {
    total-environmental-actions: (var-get total-environmental-actions),
    total-eco-tokens-generated: (var-get total-eco-tokens-generated)
  }
)

;; Private Functions

(define-private (is-eco-coordinator)
  (is-eq tx-sender (var-get eco-coordinator))
)
