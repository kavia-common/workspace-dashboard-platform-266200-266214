# Postgres Database — Workspace Dashboard Platform

This folder contains the **database schema** and a **repeatable initialization/seed approach** for:

- Users
- Organizations
- Workspaces
- Membership/roles
- User profile settings
- Analytics events (append-only)

> Note: The environment for this repo snapshot does **not** include a `db_connection.txt`.  
> If/when that file is present, it should contain a `psql postgresql://...` connection string command.  
> Until then, use your Postgres connection string/credentials provided by your runtime environment.

---

## Schema overview (ER-ish)

- `app_user` — people who can log in / act
- `organization` — top-level tenant container
- `workspace` — a workspace belongs to one organization
- `org_membership` — users can belong to orgs with roles
- `user_profile_settings` — per-user settings/preferences
- `analytics_event` — append-only event stream linked to workspace (and optionally user)

---

## Initialization / Seed approach (repeatable)

### Why this approach
- **Idempotent**: can be run multiple times safely
- **No migration framework required**: pure SQL
- **Designed to be executed one statement at a time** with `psql -c "..."`

### How to run

1) Connect to your DB (example):
```bash
psql "$DATABASE_URL"
```

2) Execute statements **one at a time** from the files in `schema/`:
- `schema/001_schema.sql` (tables, constraints)
- `schema/002_indexes.sql` (indexes)
- `schema/003_seed.sql` (seed data)

**Important:** Per platform guidance, do not run these as a single file. Copy/paste each statement individually or use `psql -c "SQL"` per statement.

---

## Recommended seed entities

Seed creates:
- Org: `Acme Inc` (slug `acme`)
- Workspaces:
  - `Marketing` (slug `marketing`)
  - `Product` (slug `product`)
- Users:
  - `Demo Admin` (admin@example.com)
  - `Demo Member` (member@example.com)
- Memberships tying them together
- A small set of analytics events across the last ~30 days

You can edit the seed data in `schema/003_seed.sql` as needed.

---

## Notes for backend integration (later step)

When the backend is implemented, it will typically need:
- Query patterns by `workspace_id` + time range
- Aggregations by `event_name`
- Optional filtering by `user_id`

The indexes in `schema/002_indexes.sql` are tuned for those access patterns.

---
