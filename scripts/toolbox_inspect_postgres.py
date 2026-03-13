#!/usr/bin/env python3
"""
Inspect Azure PostgreSQL (Olist) from the toolbox VM.
Uses psycopg2; connection from env: PGHOST, PGUSER, PGPASSWORD, PGDATABASE.
Lists tables from information_schema and prints first N rows of a table.
Usage:
  export PGHOST=... PGUSER=... PGPASSWORD=... PGDATABASE=retailflow
  python3 toolbox_inspect_postgres.py [--table TABLE] [--rows N]
"""

import os
import sys
import argparse

try:
    import psycopg2
except ImportError:
    print("Install psycopg2: pip3 install --user psycopg2-binary", file=sys.stderr)
    sys.exit(1)


def get_conn():
    host = os.environ.get("PGHOST")
    user = os.environ.get("PGUSER")
    password = os.environ.get("PGPASSWORD")
    dbname = os.environ.get("PGDATABASE", "retailflow")
    if not all([host, user, password]):
        print("Set PGHOST, PGUSER, PGPASSWORD (and optionally PGDATABASE).", file=sys.stderr)
        sys.exit(1)
    return psycopg2.connect(
        host=host,
        user=user,
        password=password,
        dbname=dbname,
        sslmode="require",
    )


def list_tables(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
            ORDER BY table_name
        """)
        return [row[0] for row in cur.fetchall()]


def preview_table(conn, table: str, n: int = 5):
    with conn.cursor() as cur:
        cur.execute(f"SELECT * FROM {table} LIMIT %s", (n,))
        rows = cur.fetchall()
        colnames = [d[0] for d in cur.description]
    return colnames, rows


def main():
    ap = argparse.ArgumentParser(description="Inspect PostgreSQL tables (Olist)")
    ap.add_argument("--table", "-t", help="Table to preview (default: list tables only)")
    ap.add_argument("--rows", "-n", type=int, default=5, help="Number of rows to show (default: 5)")
    args = ap.parse_args()

    conn = get_conn()
    try:
        tables = list_tables(conn)
        print("Tables in public schema:", ", ".join(tables))

        if args.table:
            if args.table not in tables:
                print(f"Unknown table: {args.table}", file=sys.stderr)
                sys.exit(1)
            cols, rows = preview_table(conn, args.table, args.rows)
            print(f"\nFirst {args.rows} rows of {args.table}:")
            print("Columns:", cols)
            for row in rows:
                print(row)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
