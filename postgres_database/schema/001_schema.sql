-- 001_schema.sql
-- Core schema for workspace dashboard platform.
-- Designed to be executed statement-by-statement via `psql -c "..."`.
--
-- Idempotency notes:
-- - Uses `CREATE ... IF NOT EXISTS` where possible.
-- - For triggers/functions, uses CREATE OR REPLACE.

-- Enable useful extensions (uuid generation, case-insensitive text)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS citext;

-- Users
CREATE TABLE IF NOT EXISTS app_user (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email CITEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  password_hash TEXT NULL, -- for backend auth step (store hashed password)
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Organizations
CREATE TABLE IF NOT EXISTS organization (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Workspaces
CREATE TABLE IF NOT EXISTS workspace (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  organization_id UUID NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT workspace_org_slug_uk UNIQUE (organization_id, slug)
);

-- Memberships / Roles
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'org_role') THEN
    CREATE TYPE org_role AS ENUM ('owner', 'admin', 'member', 'viewer');
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS org_membership (
  organization_id UUID NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  role org_role NOT NULL DEFAULT 'member',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, user_id)
);

-- User profile settings (lightweight, extensible JSON)
CREATE TABLE IF NOT EXISTS user_profile_settings (
  user_id UUID PRIMARY KEY REFERENCES app_user(id) ON DELETE CASCADE,
  timezone TEXT NULL,
  theme TEXT NULL, -- e.g. "light", "retro"
  settings JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Analytics events (append-only)
CREATE TABLE IF NOT EXISTS analytics_event (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  workspace_id UUID NOT NULL REFERENCES workspace(id) ON DELETE CASCADE,
  organization_id UUID NOT NULL REFERENCES organization(id) ON DELETE CASCADE,
  user_id UUID NULL REFERENCES app_user(id) ON DELETE SET NULL,
  event_name TEXT NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL,
  source TEXT NULL, -- e.g. "web", "api", "system"
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Keep organization_id consistent with workspace.organization_id
-- (Denormalization for query speed; enforced on insert/update.)
CREATE OR REPLACE FUNCTION analytics_event_set_org_id()
RETURNS TRIGGER AS $$
BEGIN
  SELECT w.organization_id INTO NEW.organization_id
  FROM workspace w
  WHERE w.id = NEW.workspace_id;

  IF NEW.organization_id IS NULL THEN
    RAISE EXCEPTION 'Invalid workspace_id %, cannot determine organization_id', NEW.workspace_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_analytics_event_set_org_id ON analytics_event;
CREATE TRIGGER trg_analytics_event_set_org_id
BEFORE INSERT OR UPDATE OF workspace_id
ON analytics_event
FOR EACH ROW
EXECUTE FUNCTION analytics_event_set_org_id();

-- Generic updated_at trigger
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_app_user_updated_at ON app_user;
CREATE TRIGGER trg_app_user_updated_at
BEFORE UPDATE ON app_user
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_organization_updated_at ON organization;
CREATE TRIGGER trg_organization_updated_at
BEFORE UPDATE ON organization
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_workspace_updated_at ON workspace;
CREATE TRIGGER trg_workspace_updated_at
BEFORE UPDATE ON workspace
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_user_profile_settings_updated_at ON user_profile_settings;
CREATE TRIGGER trg_user_profile_settings_updated_at
BEFORE UPDATE ON user_profile_settings
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();
