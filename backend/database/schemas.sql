-- =============================================================================
-- HYPETERM — RESELLER OS
-- Complete Database Schema
-- PostgreSQL / Supabase compatible
-- =============================================================================


-- =============================================================================
-- USERS
-- id matches Supabase Auth UUID
-- =============================================================================

CREATE TABLE users (
    id                  UUID PRIMARY KEY,
    email               VARCHAR(255) UNIQUE NOT NULL,
    username            VARCHAR(100) UNIQUE NOT NULL,
    created_at          TIMESTAMP DEFAULT NOW()
);


-- =============================================================================
-- ITEMS CATALOG
-- One row per item type (e.g. "Jordan 1 Chicago" as a concept).
-- Not individual physical items — those live in holdings.
-- =============================================================================

CREATE TABLE items (
    id                  SERIAL PRIMARY KEY,
    name                VARCHAR(255) NOT NULL,
    brand               VARCHAR(100) NOT NULL,
    colorway            VARCHAR(255),
    sku                 VARCHAR(100) UNIQUE,
    retail_price        DECIMAL(10,2),
    release_date        DATE,
    category            VARCHAR(50) NOT NULL
                            CHECK (category IN ('sneaker','vintage','card','watch','other')),
    image_url           TEXT,
    created_at          TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_items_category ON items(category);
CREATE INDEX idx_items_brand    ON items(brand);


-- =============================================================================
-- PRICE HISTORY
-- Market price snapshots per item, per condition, per source.
-- Condition matters — DS and worn are different markets.
-- =============================================================================

CREATE TABLE price_history (
    id                  SERIAL PRIMARY KEY,
    item_id             INT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    price               DECIMAL(10,2) NOT NULL,
    condition           VARCHAR(20) NOT NULL DEFAULT 'DS'
                            CHECK (condition IN ('DS','VNDS','used','worn')),
    source              VARCHAR(50),
    recorded_at         TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_price_history_item_id     ON price_history(item_id);
CREATE INDEX idx_price_history_recorded_at ON price_history(recorded_at DESC);


-- =============================================================================
-- PLATFORM CONFIG
-- Fee structures, average DOM, and stale thresholds per platform and category.
-- Avoids hardcoding business logic in the application layer.
-- =============================================================================

CREATE TABLE platform_config (
    id                      SERIAL PRIMARY KEY,
    platform                VARCHAR(50) NOT NULL,
    category                VARCHAR(50),
    fee_pct                 DECIMAL(5,2) NOT NULL,
    avg_dom_days            INT,
    stale_threshold_days    INT DEFAULT 21,
    payout_delay_days       INT,
    UNIQUE (platform, category)
);

INSERT INTO platform_config (platform, category, fee_pct, avg_dom_days, stale_threshold_days, payout_delay_days) VALUES
    ('stockx',  'sneaker',  9.5,  7,  14, 7),
    ('stockx',  'card',     9.5,  12, 21, 7),
    ('stockx',  'watch',    9.5,  20, 30, 7),
    ('goat',    'sneaker',  9.5,  8,  14, 7),
    ('grailed', 'sneaker',  4.9,  14, 21, 5),
    ('grailed', 'vintage',  4.9,  18, 28, 5),
    ('grailed', 'card',     4.9,  14, 21, 5),
    ('ebay',    'sneaker',  12.9, 10, 21, 3),
    ('ebay',    'vintage',  12.9, 14, 28, 3),
    ('ebay',    'card',     12.9, 10, 21, 3),
    ('ebay',    'watch',    12.9, 21, 35, 3),
    ('depop',   'vintage',  10.0, 20, 30, 5);


-- =============================================================================
-- HOLDINGS
-- One row per physical item a user owns or has owned.
-- Not one row per item type — each physical sneaker is its own row.
-- =============================================================================

CREATE TABLE holdings (
    id                  SERIAL PRIMARY KEY,
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    item_id             INT  NOT NULL REFERENCES items(id),

    -- Physical attributes
    size                VARCHAR(20),
    condition           VARCHAR(20) NOT NULL DEFAULT 'DS'
                            CHECK (condition IN ('DS','VNDS','used','worn')),
    notes               TEXT,
    images              TEXT[],

    -- Purchase record
    purchase_price      DECIMAL(10,2) NOT NULL,
    purchase_date       DATE,
    purchase_platform   VARCHAR(50),

    -- Pipeline state
    -- holding   → item is in possession, not listed
    -- listed    → item has at least one active listing
    -- pending   → item sold, awaiting payout
    -- completed → payout received, item fully exited
    status              VARCHAR(20) NOT NULL DEFAULT 'holding'
                            CHECK (status IN ('holding','listed','pending','completed')),

    created_at          TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_holdings_user_id ON holdings(user_id);
CREATE INDEX idx_holdings_item_id ON holdings(item_id);
CREATE INDEX idx_holdings_status  ON holdings(status);


-- =============================================================================
-- LISTINGS
-- One row per listing attempt per platform.
-- A holding can have multiple listings (e.g. StockX + Grailed simultaneously),
-- but only one active listing per platform at a time.
-- =============================================================================

CREATE TABLE listings (
    id                      SERIAL PRIMARY KEY,
    holding_id              INT NOT NULL REFERENCES holdings(id) ON DELETE CASCADE,
    platform                VARCHAR(50) NOT NULL,

    -- Listing details
    ask_price               DECIMAL(10,2) NOT NULL,
    listed_at               TIMESTAMP DEFAULT NOW(),
    is_active               BOOLEAN DEFAULT TRUE,

    -- Sale details (populated when sold)
    sold_at                 TIMESTAMP,
    sale_price              DECIMAL(10,2),

    -- Payout details (populated after sale)
    platform_fee_pct        DECIMAL(5,2),
    platform_fee_amount     DECIMAL(10,2),
    net_payout              DECIMAL(10,2),
    payout_expected_date    DATE,
    payout_received_date    DATE,

    created_at              TIMESTAMP DEFAULT NOW()
);

-- Prevents duplicate active listings on the same platform for the same holding
CREATE UNIQUE INDEX idx_one_active_listing_per_platform
    ON listings (holding_id, platform)
    WHERE is_active = TRUE;

CREATE INDEX idx_listings_holding_id ON listings(holding_id);
CREATE INDEX idx_listings_platform   ON listings(platform);
CREATE INDEX idx_listings_is_active  ON listings(is_active);


-- =============================================================================
-- INDEXES
-- Composite market indexes (Jordan Index, Yeezy Index, Vintage Denim Index etc.)
-- Track the health of a segment of the market over time.
-- =============================================================================

CREATE TABLE indexes (
    id                  SERIAL PRIMARY KEY,
    name                VARCHAR(255) NOT NULL,
    description         TEXT,
    created_at          TIMESTAMP DEFAULT NOW()
);

CREATE TABLE index_members (
    index_id            INT NOT NULL REFERENCES indexes(id) ON DELETE CASCADE,
    item_id             INT NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    weight              DECIMAL(5,2) DEFAULT 1.0,
    PRIMARY KEY (index_id, item_id)
);

CREATE TABLE index_history (
    id                  SERIAL PRIMARY KEY,
    index_id            INT NOT NULL REFERENCES indexes(id) ON DELETE CASCADE,
    value               DECIMAL(10,2) NOT NULL,
    recorded_at         TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_index_history_index_id     ON index_history(index_id);
CREATE INDEX idx_index_history_recorded_at  ON index_history(recorded_at DESC);


-- =============================================================================
-- VIEWS
-- Pre-built queries for the most common reads in the application.
-- =============================================================================

-- Portfolio view: all active holdings with latest market price and unrealized P&L
CREATE VIEW v_portfolio AS
SELECT
    h.id                                                        AS holding_id,
    h.user_id,
    i.id                                                        AS item_id,
    i.name,
    i.brand,
    i.category,
    i.image_url,
    h.size,
    h.condition,
    h.purchase_price,
    h.purchase_date,
    h.status,
    h.notes,
    h.images,
    ph.price                                                    AS current_price,
    ph.recorded_at                                              AS price_updated_at,
    ROUND((ph.price - h.purchase_price), 2)                    AS unrealized_pnl,
    ROUND(((ph.price - h.purchase_price) / h.purchase_price * 100), 2)
                                                                AS roi_pct
FROM holdings h
JOIN items i
    ON h.item_id = i.id
LEFT JOIN LATERAL (
    SELECT price, recorded_at
    FROM price_history
    WHERE item_id = h.item_id
      AND condition = h.condition
    ORDER BY recorded_at DESC
    LIMIT 1
) ph ON TRUE
WHERE h.status != 'completed';


-- Pipeline view: listed items with days on market and stale flag
CREATE VIEW v_pipeline_listed AS
SELECT
    h.id                                                        AS holding_id,
    h.user_id,
    i.name,
    i.category,
    h.size,
    h.condition,
    h.purchase_price,
    l.id                                                        AS listing_id,
    l.platform,
    l.ask_price,
    l.listed_at,
    EXTRACT(DAY FROM NOW() - l.listed_at)::INT                 AS dom,
    pc.stale_threshold_days,
    EXTRACT(DAY FROM NOW() - l.listed_at) > pc.stale_threshold_days
                                                                AS is_stale,
    pc.fee_pct,
    ROUND(l.ask_price * (1 - pc.fee_pct / 100), 2)            AS estimated_net
FROM holdings h
JOIN items i
    ON h.item_id = i.id
JOIN listings l
    ON l.holding_id = h.id AND l.is_active = TRUE
LEFT JOIN platform_config pc
    ON pc.platform = l.platform AND pc.category = i.category
WHERE h.status = 'listed';


-- Cash flow view: pending payouts ordered by expected date
CREATE VIEW v_cashflow_pending AS
SELECT
    h.id                                                        AS holding_id,
    h.user_id,
    i.name,
    i.category,
    l.platform,
    l.sale_price,
    l.platform_fee_pct,
    l.platform_fee_amount,
    l.net_payout,
    l.sold_at,
    l.payout_expected_date,
    l.payout_received_date,
    l.payout_received_date IS NULL                             AS payout_outstanding
FROM listings l
JOIN holdings h
    ON l.holding_id = h.id
JOIN items i
    ON h.item_id = i.id
WHERE h.status = 'pending'
ORDER BY l.payout_expected_date ASC;


-- Liquidity history: avg days on market per category from completed sales
CREATE VIEW v_liquidity_by_category AS
SELECT
    h.user_id,
    i.category,
    l.platform,
    ROUND(AVG(EXTRACT(DAY FROM l.sold_at - l.listed_at)), 1)   AS avg_dom_days,
    ROUND(AVG(l.net_payout - h.purchase_price), 2)              AS avg_net_pnl,
    ROUND(AVG((l.net_payout - h.purchase_price)
        / h.purchase_price * 100), 2)                           AS avg_roi_pct,
    COUNT(*)                                                    AS total_sold
FROM listings l
JOIN holdings h
    ON l.holding_id = h.id
JOIN items i
    ON h.item_id = i.id
WHERE l.sold_at IS NOT NULL
GROUP BY h.user_id, i.category, l.platform;


-- Realized P&L: completed sales with full breakdown
CREATE VIEW v_realized_pnl AS
SELECT
    h.user_id,
    h.id                                                        AS holding_id,
    i.name,
    i.category,
    h.size,
    h.condition,
    h.purchase_price,
    h.purchase_date,
    l.platform,
    l.sale_price,
    l.platform_fee_pct,
    l.platform_fee_amount,
    l.net_payout,
    l.sold_at,
    ROUND(l.net_payout - h.purchase_price, 2)                  AS realized_pnl,
    ROUND((l.net_payout - h.purchase_price)
        / h.purchase_price * 100, 2)                           AS realized_roi_pct,
    EXTRACT(DAY FROM l.sold_at - h.purchase_date)::INT         AS days_held
FROM listings l
JOIN holdings h
    ON l.holding_id = h.id
JOIN items i
    ON h.item_id = i.id
WHERE h.status = 'completed'
  AND l.sold_at IS NOT NULL
ORDER BY l.sold_at DESC;


-- =============================================================================
-- FUNCTIONS
-- Helper functions for common state transitions.
-- Call these from your application layer rather than writing raw UPDATE queries.
-- =============================================================================

-- Mark a holding as listed when a new listing is created
CREATE OR REPLACE FUNCTION fn_on_listing_created()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE holdings SET status = 'listed' WHERE id = NEW.holding_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_listing_created
    AFTER INSERT ON listings
    FOR EACH ROW
    EXECUTE FUNCTION fn_on_listing_created();


-- When a listing is marked sold, compute fees, set payout date, move holding to pending
CREATE OR REPLACE FUNCTION fn_on_listing_sold()
RETURNS TRIGGER AS $$
DECLARE
    v_fee_pct       DECIMAL(5,2);
    v_payout_days   INT;
    v_category      VARCHAR(50);
BEGIN
    IF NEW.sold_at IS NOT NULL AND OLD.sold_at IS NULL THEN

        SELECT i.category INTO v_category
        FROM holdings h
        JOIN items i ON h.item_id = i.id
        WHERE h.id = NEW.holding_id;

        SELECT fee_pct, payout_delay_days
        INTO v_fee_pct, v_payout_days
        FROM platform_config
        WHERE platform = NEW.platform AND category = v_category
        LIMIT 1;

        -- Fall back to ask_price fee if platform_config missing
        v_fee_pct := COALESCE(v_fee_pct, 9.5);
        v_payout_days := COALESCE(v_payout_days, 7);

        NEW.platform_fee_pct    := v_fee_pct;
        NEW.platform_fee_amount := ROUND(NEW.sale_price * v_fee_pct / 100, 2);
        NEW.net_payout          := ROUND(NEW.sale_price * (1 - v_fee_pct / 100), 2);
        NEW.payout_expected_date := (NEW.sold_at + (v_payout_days || ' days')::INTERVAL)::DATE;
        NEW.is_active           := FALSE;

        UPDATE holdings SET status = 'pending' WHERE id = NEW.holding_id;

    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_listing_sold
    BEFORE UPDATE ON listings
    FOR EACH ROW
    EXECUTE FUNCTION fn_on_listing_sold();


-- When payout is received, move holding to completed
CREATE OR REPLACE FUNCTION fn_on_payout_received()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.payout_received_date IS NOT NULL AND OLD.payout_received_date IS NULL THEN
        UPDATE holdings SET status = 'completed' WHERE id = NEW.holding_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_payout_received
    BEFORE UPDATE ON listings
    FOR EACH ROW
    EXECUTE FUNCTION fn_on_payout_received();


-- =============================================================================
-- ROW LEVEL SECURITY (Supabase)
-- Users can only read and write their own data.
-- Enable RLS on all user-facing tables after creating policies.
-- =============================================================================

ALTER TABLE holdings        ENABLE ROW LEVEL SECURITY;
ALTER TABLE listings        ENABLE ROW LEVEL SECURITY;

CREATE POLICY holdings_user_policy ON holdings
    USING (user_id = auth.uid());

CREATE POLICY listings_user_policy ON listings
    USING (
        holding_id IN (
            SELECT id FROM holdings WHERE user_id = auth.uid()
        )
    );

-- items, price_history, indexes, platform_config are read-only for all users
ALTER TABLE items            ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_history    ENABLE ROW LEVEL SECURITY;
ALTER TABLE indexes          ENABLE ROW LEVEL SECURITY;
ALTER TABLE index_members    ENABLE ROW LEVEL SECURITY;
ALTER TABLE index_history    ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_config  ENABLE ROW LEVEL SECURITY;

CREATE POLICY items_read_all            ON items           FOR SELECT USING (TRUE);
CREATE POLICY price_history_read_all    ON price_history   FOR SELECT USING (TRUE);
CREATE POLICY indexes_read_all          ON indexes         FOR SELECT USING (TRUE);
CREATE POLICY index_members_read_all    ON index_members   FOR SELECT USING (TRUE);
CREATE POLICY index_history_read_all    ON index_history   FOR SELECT USING (TRUE);
CREATE POLICY platform_config_read_all  ON platform_config FOR SELECT USING (TRUE);