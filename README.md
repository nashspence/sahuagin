# Sahuagin Database

This repository contains the PostgreSQL schema and stored procedures for the Sahuagin project. The SQL files live under `sql/` and are loaded automatically when the database container starts. The entry point `00_init.sql` includes the individual definitions from the `schema`, `functions`, and `procedures` folders.

## Starting the database

A minimal Docker Compose setup runs PostgreSQL and loads the schema:

```bash
docker-compose up -d
```

PostgreSQL will be available on port `5432` with the default credentials `postgres`/`postgres`.

## Schema

All tables, functions, and procedures are organized in separate files under `sql/`. The original Jupyter notebooks are kept in `notebooks/` for historical reference.
