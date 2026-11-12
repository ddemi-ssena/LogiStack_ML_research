CREATE SCHEMA IF NOT EXISTS gold;

CREATE TABLE IF NOT EXISTS gold.mart_customer_segments (
    customer_unique_id TEXT PRIMARY KEY,
    recency INTEGER NOT NULL,
    frequency BIGINT NOT NULL,
    monetary NUMERIC(16, 2) NOT NULL,
    cluster_id INTEGER NOT NULL,
    segment_name TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
