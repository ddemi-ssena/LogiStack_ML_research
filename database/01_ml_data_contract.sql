-- Minimal analytical contract consumed by this ML repository.
-- Core Gold facts and Silver reviews are created by the upstream data platform.
CREATE SCHEMA IF NOT EXISTS gold;

CREATE TABLE IF NOT EXISTS gold.mart_customer_rfm (
    customer_unique_id TEXT PRIMARY KEY,
    recency_days INTEGER NOT NULL,
    frequency BIGINT NOT NULL,
    monetary NUMERIC(16, 2) NOT NULL,
    reference_date DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS gold.mart_customer_segments (
    customer_unique_id TEXT PRIMARY KEY,
    recency INTEGER NOT NULL,
    frequency BIGINT NOT NULL,
    monetary NUMERIC(16, 2) NOT NULL,
    cluster_id INTEGER NOT NULL,
    segment_name TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
