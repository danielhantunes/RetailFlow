"""Unit tests for ingestion metadata helpers."""
from datetime import datetime, timezone

import pytest


def ingestion_date_utc() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def batch_id() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def raw_path(base: str, entity: str, ingestion_dt: str | None = None) -> str:
    dt = ingestion_dt or ingestion_date_utc()
    return f"{base.rstrip('/')}/data/raw/{entity}/ingestion_date={dt}"


class TestIngestionMetadata:
    def test_ingestion_date_format(self):
        d = ingestion_date_utc()
        assert len(d) == 10
        assert d[4] == "-" and d[7] == "-"

    def test_batch_id_format(self):
        b = batch_id()
        assert "T" in b
        assert "Z" in b

    def test_raw_path(self):
        p = raw_path("abfss://raw@sa.dfs.core.windows.net", "orders", "2025-02-18")
        assert "orders" in p
        assert "ingestion_date=2025-02-18" in p
