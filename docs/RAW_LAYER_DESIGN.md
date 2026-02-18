# RetailFlow — RAW Layer Design

## Principles

1. **Immutability** — Data is never updated or deleted in RAW; only appends.
2. **Exact copy** — No transformations; store bytes as received (optionally with a wrapper for metadata).
3. **Replay / reprocessing** — Any date range or batch can be re-read and re-pipelined to Bronze without altering RAW.
4. **Schema evolution** — New fields in source do not require rewriting RAW; downstream Bronze/Silver handle evolution.

## Layout on ADLS Gen2

```
{container}/data/raw/
├── orders/
│   └── ingestion_date=2025-02-18/
│       └── batch_001_20250218T120000Z.json
├── customers/
│   └── ingestion_date=2025-02-18/
├── products/
│   └── ingestion_date=2025-02-18/
├── inventory/
│   └── ingestion_date=2025-02-18/
├── clickstream/
│   └── ingestion_date=2025-02-18/
├── payments/
│   └── ingestion_date=2025-02-18/
└── store_sales/
    └── ingestion_date=2025-02-18/
```

- **Partitioning:** `ingestion_date=YYYY-MM-DD` for efficient range scans and retention policies.
- **Naming:** `batch_{id}_{timestamp}.{ext}` or `{source_system}_{timestamp}.{ext}` to avoid overwrites and support idempotent ingestion.

## Ingestion Metadata

For each file we record (in a sidecar or in the same path naming):

- **Ingestion timestamp (UTC)** — When the file was written.
- **Source system / API endpoint** — Traceability.
- **Batch ID / Run ID** — For idempotency and replay.

Metadata can be:

- In the **filename** (e.g. `batch_001_20250218T120000Z.json`), or
- In a **manifest** table (e.g. in Delta or a small DB) keyed by path and batch_id, or
- In a **metadata column** only in Bronze (Bronze adds `_ingestion_ts`, `_source_file` when reading RAW).

RAW itself does not run SQL; it only stores files. So “add ingestion metadata” in the requirement is implemented by the **ingestion process** (notebook/script) that writes the file and optionally a manifest, and by Bronze adding `_ingestion_ts`, `_source_file` when reading.

## Formats

| Source | Format | Notes |
|--------|--------|--------|
| Orders API | JSON | One file per batch or per time window |
| Customers API | JSON | Same |
| Products | CSV | As exported from catalog system |
| Inventory | JSON or Parquet | As exported |
| Clickstream | JSON (ndjson) | One event per line |
| Payments | JSON | One file per batch |
| Store sales (SQL) | Parquet or CSV | Extract from operational DB |

## Retention and Lifecycle

- Retention policy (e.g. 90 days in hot, then cool/archive) can be applied on the RAW container using Azure lifecycle rules.
- Deletion of RAW data is out of scope of the pipeline; only append and read.

## Design Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Partition key | `ingestion_date` | Simple, aligns with daily batches and reprocessing |
| Immutability | Append-only | Replay and audit; no updates/deletes in RAW |
| No transforms in RAW | Strict | Keeps RAW as source of truth; evolution in Bronze/Silver |
| File naming | Include batch + timestamp | Avoid overwrites; clear ordering and replay |
| Metadata | Filename + Bronze audit cols | No schema in RAW; audit in Bronze |
