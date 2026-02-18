#!/usr/bin/env bash
# Create RAW folder structure on ADLS (run via Azure CLI or Databricks fs)
# Prereq: az storage fs directory create; or use Databricks notebook to create empty dirs

set -e
RAW_ROOT="${RAW_ROOT:-abfss://raw@retailflowdevsa.dfs.core.windows.net/data/raw}"
for entity in orders customers products inventory clickstream payments store_sales; do
  echo "Creating $RAW_ROOT/$entity"
  # az storage fs directory create -n "data/raw/$entity" -f raw --account-name retailflowdevsa
done
