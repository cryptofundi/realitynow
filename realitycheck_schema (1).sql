-- ============================================================
-- RealityCheck — Indexer Database Schema
-- PostgreSQL · v1 · Locked
-- Rebuildable from on-chain events at any time
-- ============================================================

-- ── Extensions ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- GROUP 1: CHAIN MIRROR TABLES
-- Direct reflection of on-chain events.
-- Rebuilt from chain if wiped.
-- ============================================================

CREATE TABLE posts (
  -- Primary key comes from contract, not DB sequence
  post_id               BIGINT          PRIMARY KEY,

  -- Location
  location_hash         CHAR(66)        NOT NULL,  -- keccak256(geohash+category) hex
  geohash_full          VARCHAR(12)     NOT NULL,  -- 6-char full geohash, stored by relay
  geohash_prefix        VARCHAR(6)      NOT NULL,  -- first 5 chars, for feed grouping
  zone_prefix           VARCHAR(4)      NOT NULL,  -- first 4 chars, for zone allow/block

  -- Post content
  category              SMALLINT        NOT NULL CHECK (category BETWEEN 0 AND 5),
  state                 SMALLINT        NOT NULL CHECK (state BETWEEN 0 AND 4),
  poster_wallet         VARCHAR(42)     NOT NULL,  -- Ethereum address
  reporter_type         SMALLINT        NOT NULL CHECK (reporter_type IN (0,1)), -- 0=WALLET 1=UPI
  reporter_id           CHAR(66)        NOT NULL,  -- abstract identity hash
  content_hash          CHAR(66)        NOT NULL,  -- keccak256 of IPFS CID
  ipfs_cid              VARCHAR(80),               -- full IPFS CID, stored by relay
  fee_amount_wei        NUMERIC(30)     NOT NULL,

  -- Chain metadata
  block_timestamp       TIMESTAMPTZ     NOT NULL,
  block_number          BIGINT          NOT NULL,
  tx_hash               CHAR(66)        NOT NULL,

  -- Resolution (NULL until PostFinalized event received)
  outcome               SMALLINT        CHECK (outcome IN (0,1,2)), -- 0=VALID 1=INVALID 2=INCONCLUSIVE
  confidence            SMALLINT        CHECK (confidence BETWEEN 0 AND 100),
  finalized_at          TIMESTAMPTZ,
  -- FIX 2: idempotency guard
  finalized             BOOLEAN         NOT NULL DEFAULT FALSE,

  -- Reward evaluation (NULL until RewardEvaluated event)
  reward_eligible       BOOLEAN,
  reward_reason_code    SMALLINT        CHECK (reward_reason_code BETWEEN 1 AND 5),
  slot_number           SMALLINT        CHECK (slot_number BETWEEN 1 AND 3),

  -- Timestamps
  created_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- Indexes on posts
CREATE INDEX idx_posts_location_hash      ON posts (location_hash);
CREATE INDEX idx_posts_geohash_prefix     ON posts (geohash_prefix);
CREATE INDEX idx_posts_zone_prefix        ON posts (zone_prefix);
CREATE INDEX idx_posts_poster_wallet      ON posts (poster_wallet);
CREATE INDEX idx_posts_block_timestamp    ON posts (block_timestamp DESC);
CREATE INDEX idx_posts_outcome            ON posts (outcome) WHERE outcome IS NOT NULL;
CREATE INDEX idx_posts_reporter_id        ON posts (reporter_id); -- for UPI claim queries

-- ────────────────────────────────────────────────────────────

CREATE TABLE validations (
  id                    BIGSERIAL       PRIMARY KEY,
  post_id               BIGINT          NOT NULL REFERENCES posts(post_id),
  validator_wallet      VARCHAR(42)     NOT NULL,
  vote                  BOOLEAN         NOT NULL, -- true=Confirm false=Dispute
  was_correct           BOOLEAN,                  -- NULL until post finalized
  reward_paid           BOOLEAN         NOT NULL DEFAULT FALSE,
  reward_amount_wei     NUMERIC(30),
  block_timestamp       TIMESTAMPTZ     NOT NULL,
  block_number          BIGINT          NOT NULL,
  tx_hash               CHAR(66)        NOT NULL,

  -- FIX 2: idempotency — one vote per validator per post
  CONSTRAINT uq_validation UNIQUE (post_id, validator_wallet)
);

-- Indexes on validations
CREATE INDEX idx_validations_post_id         ON validations (post_id);
CREATE INDEX idx_validations_validator_wallet ON validations (validator_wallet);
CREATE INDEX idx_validations_post_timestamp  ON validations (post_id, block_timestamp); -- compound

-- ────────────────────────────────────────────────────────────

CREATE TABLE rewards (
  id                    BIGSERIAL       PRIMARY KEY,
  post_id               BIGINT          NOT NULL REFERENCES posts(post_id),
  location_hash         CHAR(66)        NOT NULL,  -- denormalized from event, avoids join
  recipient_wallet      VARCHAR(42)     NOT NULL,
  -- FIX 3: explicit reporter_id for UPI claim flow
  reporter_id           CHAR(66)        NOT NULL,  -- matches posts.reporter_id for UPI aggregation
  reward_type           SMALLINT        NOT NULL CHECK (reward_type IN (0,1)), -- 0=PostReward 1=ValidatorReward
  amount_wei            NUMERIC(30)     NOT NULL,
  slot_number           SMALLINT        CHECK (slot_number BETWEEN 1 AND 3), -- NULL for validator rewards
  claimed               BOOLEAN         NOT NULL DEFAULT FALSE,
  claimed_at            TIMESTAMPTZ,
  block_timestamp       TIMESTAMPTZ     NOT NULL,
  block_number          BIGINT          NOT NULL,
  tx_hash               CHAR(66)        NOT NULL
);

-- Indexes on rewards
CREATE INDEX idx_rewards_post_id            ON rewards (post_id);
CREATE INDEX idx_rewards_location_hash      ON rewards (location_hash);
CREATE INDEX idx_rewards_recipient_wallet   ON rewards (recipient_wallet);
CREATE INDEX idx_rewards_reporter_id        ON rewards (reporter_id);  -- UPI claim lookup
CREATE INDEX idx_rewards_unclaimed          ON rewards (recipient_wallet, claimed) WHERE claimed = FALSE;
CREATE INDEX idx_rewards_reporter_unclaimed ON rewards (reporter_id, claimed) WHERE claimed = FALSE; -- UPI claim

-- ────────────────────────────────────────────────────────────

CREATE TABLE reputation_events (
  id                    BIGSERIAL       PRIMARY KEY,
  wallet                VARCHAR(42)     NOT NULL,
  new_score             INTEGER         NOT NULL,  -- score × 100, divide by 100 for display
  delta                 SMALLINT        NOT NULL,  -- signed: positive=gain, negative=penalty
  reason                SMALLINT        NOT NULL CHECK (reason BETWEEN 0 AND 4),
  -- 0=PostValid 1=PostInvalid 2=ValidationCorrect 3=ValidationWrong 4=Decay
  block_timestamp       TIMESTAMPTZ     NOT NULL,
  block_number          BIGINT          NOT NULL,
  tx_hash               CHAR(66)        NOT NULL
);

CREATE INDEX idx_rep_events_wallet ON reputation_events (wallet);


-- ============================================================
-- GROUP 2: DERIVED STATE TABLES
-- Computed from chain mirror. Drives all feed queries.
-- Can be dropped and rebuilt from posts/validations/rewards.
-- ============================================================

CREATE TABLE location_states (
  -- Composite PK: one row per location+category
  location_hash         CHAR(66)        NOT NULL,
  category              SMALLINT        NOT NULL CHECK (category BETWEEN 0 AND 5),
  PRIMARY KEY (location_hash, category),

  -- Display info (denormalized from posts to avoid join on every feed load)
  geohash_full          VARCHAR(12)     NOT NULL,
  geohash_prefix        VARCHAR(6)      NOT NULL,

  -- Current truth
  current_state         SMALLINT,                 -- most recent valid state
  confidence            SMALLINT,                 -- confidence of current state
  last_valid_post_id    BIGINT          REFERENCES posts(post_id),
  last_valid_at         TIMESTAMPTZ,              -- block_timestamp of last valid post

  -- Staleness (computed by indexer worker every minute)
  -- Rule: is_stale = TRUE when NOW() - last_valid_at > staleness_window[category]
  -- Staleness window values come FROM contract (stalenessWindows mapping)
  is_stale              BOOLEAN         NOT NULL DEFAULT TRUE,

  -- Slot availability (mirrored from location_slots for fast feed query)
  slots_remaining       SMALLINT        NOT NULL DEFAULT 3,

  -- Analytics
  total_posts           INTEGER         NOT NULL DEFAULT 0,
  total_valid_posts     INTEGER         NOT NULL DEFAULT 0,

  updated_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- THE most important index in the system
-- Serves: nearby feed, gap card detection, zone filtering
CREATE INDEX idx_location_states_feed
  ON location_states (geohash_prefix, is_stale, category);

CREATE INDEX idx_location_states_stale
  ON location_states (is_stale, last_valid_at)
  WHERE is_stale = TRUE; -- partial index — only stale rows

-- ────────────────────────────────────────────────────────────

CREATE TABLE location_slots (
  -- Composite PK: one row per location per stale window
  location_hash         CHAR(66)        NOT NULL,
  window_start          TIMESTAMPTZ     NOT NULL,
  PRIMARY KEY (location_hash, window_start),

  slots_filled          SMALLINT        NOT NULL DEFAULT 0 CHECK (slots_filled BETWEEN 0 AND 3),
  slots_remaining       SMALLINT        NOT NULL DEFAULT 3 CHECK (slots_remaining BETWEEN 0 AND 3),
  window_closed         BOOLEAN         NOT NULL DEFAULT FALSE,
  first_post_id         BIGINT          REFERENCES posts(post_id),
  closed_at             TIMESTAMPTZ
);

CREATE INDEX idx_location_slots_open
  ON location_slots (location_hash, window_closed)
  WHERE window_closed = FALSE;

-- ────────────────────────────────────────────────────────────

CREATE TABLE user_stats (
  wallet                VARCHAR(42)     PRIMARY KEY,

  -- Reputation (from most recent ReputationUpdated event)
  reputation_score      INTEGER         NOT NULL DEFAULT 0,  -- divide by 100 for display
  reputation_tier       SMALLINT        NOT NULL DEFAULT 0,  -- 0=Newbie 1=Contributor 2=Trusted 3=Expert

  -- Post stats
  total_posts           INTEGER         NOT NULL DEFAULT 0,
  valid_posts           INTEGER         NOT NULL DEFAULT 0,
  invalid_posts         INTEGER         NOT NULL DEFAULT 0,

  -- Validation stats
  total_validations     INTEGER         NOT NULL DEFAULT 0,
  correct_validations   INTEGER         NOT NULL DEFAULT 0,

  -- Earnings
  total_earned_wei      NUMERIC(30)     NOT NULL DEFAULT 0,
  pending_rewards_wei   NUMERIC(30)     NOT NULL DEFAULT 0,  -- unclaimed in contract

  -- Impact metric (UX display only — not financially significant)
  people_helped         INTEGER         NOT NULL DEFAULT 0,  -- valid_posts × avg_viewers estimate

  -- Access control cache (from ReputationRegistry.isEligibleValidator())
  is_eligible_validator BOOLEAN         NOT NULL DEFAULT FALSE,

  -- Rate limiting
  hourly_validation_count SMALLINT      NOT NULL DEFAULT 0,
  hourly_window_start   TIMESTAMPTZ,

  -- Activity
  last_active_at        TIMESTAMPTZ,
  created_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_user_stats_eligible ON user_stats (is_eligible_validator) WHERE is_eligible_validator = TRUE;


-- ============================================================
-- GROUP 3: CONFIG + OPS TABLES
-- Admin config, deploy log, indexer sync state.
-- These are NOT rebuilt from chain — they are operational.
-- ============================================================

CREATE TABLE zones (
  id                    SERIAL          PRIMARY KEY,
  geohash_prefix        VARCHAR(4)      NOT NULL UNIQUE,
  city_name             VARCHAR(50)     NOT NULL,
  country               VARCHAR(50)     NOT NULL DEFAULT 'India',
  status                SMALLINT        NOT NULL DEFAULT 0,
  -- 0=inactive 1=launching_soon 2=active
  activated_at          TIMESTAMPTZ,
  reward_multiplier     NUMERIC(4,2)    NOT NULL DEFAULT 1.0,
  notes                 TEXT,
  created_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_zones_status ON zones (status);

-- Seed v1 launch zones
INSERT INTO zones (geohash_prefix, city_name, status, activated_at)
VALUES
  ('tdr5', 'Banjara Hills / Jubilee Hills, Hyderabad', 2, NOW()),
  ('te7u', 'Mumbai', 1, NULL),
  ('tdrf', 'Hitech City, Hyderabad', 1, NULL),
  ('tf0k', 'Bangalore', 1, NULL),
  ('tf2k', 'Chennai', 0, NULL);

-- ────────────────────────────────────────────────────────────

CREATE TABLE config_changes (
  -- Append-only audit log. Never deleted.
  id                    BIGSERIAL       PRIMARY KEY,
  change_type           VARCHAR(30)     NOT NULL,
  -- zone_added / zone_activated / staleness_window / reward_amount / relay_wallet / other
  target_key            VARCHAR(100),   -- e.g. zone prefix, category number
  old_value             JSONB,          -- NULL for new additions
  new_value             JSONB           NOT NULL,
  changed_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
  tx_hash               VARCHAR(66),    -- if change involved a contract call
  note                  TEXT            -- optional human comment
);

-- ────────────────────────────────────────────────────────────

CREATE TABLE indexer_checkpoints (
  -- Tracks where the indexer is up to for each contract
  contract_name         VARCHAR(30)     PRIMARY KEY,
  -- CoreProtocol / RewardTreasury / ReputationRegistry
  last_block            BIGINT          NOT NULL DEFAULT 0,
  last_tx_hash          CHAR(66),
  last_event_count      INTEGER         NOT NULL DEFAULT 0,
  is_syncing            BOOLEAN         NOT NULL DEFAULT FALSE,
  updated_at            TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- Seed with contract names
INSERT INTO indexer_checkpoints (contract_name, last_block)
VALUES
  ('CoreProtocol', 0),
  ('RewardTreasury', 0),
  ('ReputationRegistry', 0);


-- ============================================================
-- STALENESS WINDOW CONFIG VIEW
-- Single place to read per-category windows.
-- Values synced from contract on indexer startup.
-- ============================================================

CREATE TABLE staleness_windows (
  category              SMALLINT        PRIMARY KEY,
  category_name         VARCHAR(20)     NOT NULL,
  window_seconds        INTEGER         NOT NULL,
  -- Synced from contract stalenessWindows mapping on indexer startup
  last_synced_from_chain TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

INSERT INTO staleness_windows (category, category_name, window_seconds) VALUES
  (0, 'traffic',      300),   -- 5 min
  (1, 'crowd',        900),   -- 15 min
  (2, 'queue',        900),   -- 15 min
  (3, 'mall',        1200),   -- 20 min
  (4, 'weather',     1200),   -- 20 min
  (5, 'parking',      600);   -- 10 min


-- ============================================================
-- USEFUL VIEWS (optional but speeds up development)
-- ============================================================

-- Active stale locations — what shows as gap cards
CREATE VIEW stale_locations AS
SELECT
  ls.location_hash,
  ls.geohash_prefix,
  ls.category,
  ls.current_state,
  ls.confidence,
  ls.last_valid_at,
  ls.slots_remaining,
  EXTRACT(EPOCH FROM (NOW() - ls.last_valid_at)) / 60 AS minutes_since_update,
  z.city_name,
  z.reward_multiplier
FROM location_states ls
JOIN zones z ON LEFT(ls.geohash_prefix, 4) = z.geohash_prefix
WHERE ls.is_stale = TRUE
  AND ls.slots_remaining > 0
  AND z.status = 2  -- only active zones
ORDER BY ls.last_valid_at ASC;  -- stalest first = most urgent gap cards


-- Nearby feed for a given geohash prefix
-- Usage: SELECT * FROM recent_posts_by_area WHERE geohash_prefix = 'tdr5r'
CREATE VIEW recent_posts_by_area AS
SELECT
  p.post_id,
  p.geohash_prefix,
  p.category,
  p.state,
  p.confidence,
  p.outcome,
  p.ipfs_cid,
  p.block_timestamp,
  EXTRACT(EPOCH FROM (NOW() - p.block_timestamp)) / 60 AS minutes_ago,
  ls.current_state  AS location_current_state,
  ls.is_stale       AS location_is_stale,
  ls.slots_remaining
FROM posts p
JOIN location_states ls ON p.location_hash = ls.location_hash
                        AND p.category      = ls.category
WHERE p.outcome = 0  -- VALID only in main feed
ORDER BY p.block_timestamp DESC;


-- User earnings summary for profile screen
CREATE VIEW user_earnings AS
SELECT
  r.reporter_id,
  r.recipient_wallet,
  COUNT(*)                                    AS total_rewards,
  SUM(r.amount_wei)                           AS total_earned_wei,
  SUM(CASE WHEN r.claimed = FALSE
           THEN r.amount_wei ELSE 0 END)      AS unclaimed_wei,
  COUNT(CASE WHEN r.reward_type = 0 THEN 1 END) AS post_rewards,
  COUNT(CASE WHEN r.reward_type = 1 THEN 1 END) AS validator_rewards
FROM rewards r
GROUP BY r.reporter_id, r.recipient_wallet;



-- ============================================================
-- INDEXER IMPLEMENTATION NOTES
-- These are not schema changes — they are code requirements
-- for the Node.js indexer that reads this database.
-- ============================================================

-- NOTE 1: CHAIN REORG SAFETY (REQUIRED)
-- -------------------------------------------------------
-- Polygon can reorg. Events from recent blocks may be
-- replaced. The indexer MUST wait for confirmation before
-- writing derived state.
--
-- Implementation in indexer code (not DB):
--
--   const CONFIRMATION_BLOCKS = 10;
--
--   // Only process events where:
--   //   currentBlock - event.blockNumber >= CONFIRMATION_BLOCKS
--
--   // For chain mirror tables (posts, validations, rewards):
--   //   Write immediately but mark as unconfirmed
--   //   Add column: confirmed BOOLEAN DEFAULT FALSE
--   //   Set confirmed=TRUE after CONFIRMATION_BLOCKS
--
--   // For derived state tables (location_states, user_stats):
--   //   Only update AFTER event is confirmed
--   //   This prevents gap cards or feed states from being
--   //   based on blocks that later get reorged away
--
-- Practical effect:
--   ~20 second delay between on-chain event and feed update
--   Acceptable for v1 use cases (crowd, traffic, queue)

-- Add confirmation tracking to chain mirror tables:
ALTER TABLE posts        ADD COLUMN confirmed BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE validations  ADD COLUMN confirmed BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE rewards      ADD COLUMN confirmed BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX idx_posts_unconfirmed
  ON posts (block_number) WHERE confirmed = FALSE;


-- NOTE 2: EVENT VERSION HANDLING (DEFERRED TO V2)
-- -------------------------------------------------------
-- When v2 contracts are deployed, the indexer will need to
-- handle events from both v1 and v2 contract addresses.
--
-- v1 approach: single contract address per contract type.
-- No versioning needed.
--
-- When v2 is ready, add:
--
--   contract_versions
--   - contract_name VARCHAR(30)
--   - version       SMALLINT
--   - address       CHAR(42)
--   - deployed_at   TIMESTAMPTZ
--   - deprecated_at TIMESTAMPTZ
--
-- And add contract_version SMALLINT to posts, validations,
-- rewards tables so the indexer knows which ABI to use
-- when reprocessing historical events.
--
-- For now: store contract addresses in indexer_checkpoints.
ALTER TABLE indexer_checkpoints
  ADD COLUMN contract_address CHAR(42);


-- ============================================================
-- QUERY VALIDATION — 4 CRITICAL QUERIES
-- Confirm these run efficiently before writing Solidity.
-- ============================================================

-- Q1: "What's happening near me right now?"
-- Input: user's geohash prefix (5 chars) e.g. 'tdr5r'
-- Expected: sub-50ms, uses idx_location_states_feed
--
-- SELECT
--   ls.location_hash,
--   ls.category,
--   ls.current_state,
--   ls.confidence,
--   ls.last_valid_at,
--   ls.slots_remaining,
--   EXTRACT(EPOCH FROM (NOW() - ls.last_valid_at))/60 AS minutes_ago
-- FROM location_states ls
-- WHERE ls.geohash_prefix = 'tdr5r'
--   AND ls.is_stale = FALSE
-- ORDER BY ls.last_valid_at DESC;
-- ✓ Hits idx_location_states_feed (geohash_prefix, is_stale, category)


-- Q2: "Which locations are stale?" (gap card detection)
-- Input: active zone prefixes from zones table
-- Expected: sub-50ms, uses idx_location_states_stale
--
-- SELECT * FROM stale_locations
-- WHERE geohash_prefix LIKE 'tdr5%'
-- ORDER BY minutes_since_update DESC
-- LIMIT 5;
-- ✓ Uses stale_locations view which hits idx_location_states_stale


-- Q3: "How much has this user earned?"
-- Input: wallet address
-- Expected: single row lookup, sub-10ms
--
-- SELECT
--   total_earned_wei,
--   pending_rewards_wei,
--   people_helped,
--   reputation_score / 100.0 AS reputation
-- FROM user_stats
-- WHERE wallet = '0xABC...';
-- ✓ Hits primary key on user_stats


-- Q4: "Is this post eligible for reward?"
-- Input: post_id
-- Expected: sub-10ms
--
-- SELECT
--   p.post_id,
--   p.location_hash,
--   p.outcome,
--   p.block_timestamp,
--   p.reward_eligible,
--   p.reward_reason_code,
--   p.slot_number,
--   ls.slots_remaining,
--   sw.window_seconds,
--   EXTRACT(EPOCH FROM (p.block_timestamp - ls.last_valid_at)) AS seconds_since_prior
-- FROM posts p
-- JOIN location_states ls ON p.location_hash = ls.location_hash
--                         AND p.category = ls.category
-- JOIN staleness_windows sw ON p.category = sw.category
-- WHERE p.post_id = 1842;
-- ✓ All PK/FK lookups — sub-10ms guaranteed

