-- 003_seed.sql
-- Seed data for dev/demo. Execute statement-by-statement.
-- Idempotency approach:
-- - INSERT ... ON CONFLICT DO UPDATE/NOTHING
-- - Use stable slugs/emails as natural keys

-- Organization
INSERT INTO organization (name, slug)
VALUES ('Acme Inc', 'acme')
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name;

-- Workspaces
INSERT INTO workspace (organization_id, name, slug)
SELECT o.id, 'Marketing', 'marketing'
FROM organization o
WHERE o.slug = 'acme'
ON CONFLICT (organization_id, slug) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO workspace (organization_id, name, slug)
SELECT o.id, 'Product', 'product'
FROM organization o
WHERE o.slug = 'acme'
ON CONFLICT (organization_id, slug) DO UPDATE SET name = EXCLUDED.name;

-- Users (password_hash is placeholder until backend auth is implemented)
INSERT INTO app_user (email, full_name, password_hash)
VALUES ('admin@example.com', 'Demo Admin', NULL)
ON CONFLICT (email) DO UPDATE SET full_name = EXCLUDED.full_name;

INSERT INTO app_user (email, full_name, password_hash)
VALUES ('member@example.com', 'Demo Member', NULL)
ON CONFLICT (email) DO UPDATE SET full_name = EXCLUDED.full_name;

-- Profile settings
INSERT INTO user_profile_settings (user_id, timezone, theme, settings)
SELECT u.id, 'UTC', 'light', '{"dashboard": {"defaultRangeDays": 30}}'::jsonb
FROM app_user u
WHERE u.email = 'admin@example.com'
ON CONFLICT (user_id) DO UPDATE
SET timezone = EXCLUDED.timezone,
    theme = EXCLUDED.theme,
    settings = EXCLUDED.settings;

INSERT INTO user_profile_settings (user_id, timezone, theme, settings)
SELECT u.id, 'UTC', 'light', '{"dashboard": {"defaultRangeDays": 7}}'::jsonb
FROM app_user u
WHERE u.email = 'member@example.com'
ON CONFLICT (user_id) DO UPDATE
SET timezone = EXCLUDED.timezone,
    theme = EXCLUDED.theme,
    settings = EXCLUDED.settings;

-- Memberships
INSERT INTO org_membership (organization_id, user_id, role)
SELECT o.id, u.id, 'admin'::org_role
FROM organization o
JOIN app_user u ON u.email = 'admin@example.com'
WHERE o.slug = 'acme'
ON CONFLICT (organization_id, user_id) DO UPDATE SET role = EXCLUDED.role;

INSERT INTO org_membership (organization_id, user_id, role)
SELECT o.id, u.id, 'member'::org_role
FROM organization o
JOIN app_user u ON u.email = 'member@example.com'
WHERE o.slug = 'acme'
ON CONFLICT (organization_id, user_id) DO UPDATE SET role = EXCLUDED.role;

-- Analytics events
-- (We insert a small, deterministic set of events across recent dates.)
-- Marketing workspace events
INSERT INTO analytics_event (workspace_id, user_id, event_name, occurred_at, source, metadata)
SELECT w.id,
       (SELECT id FROM app_user WHERE email = 'admin@example.com'),
       'page_view',
       now() - interval '1 day',
       'web',
       '{"path": "/dashboard"}'::jsonb
FROM workspace w
JOIN organization o ON o.id = w.organization_id
WHERE o.slug = 'acme' AND w.slug = 'marketing';

INSERT INTO analytics_event (workspace_id, user_id, event_name, occurred_at, source, metadata)
SELECT w.id,
       (SELECT id FROM app_user WHERE email = 'member@example.com'),
       'widget_add',
       now() - interval '2 days',
       'web',
       '{"widget": "TopEvents"}'::jsonb
FROM workspace w
JOIN organization o ON o.id = w.organization_id
WHERE o.slug = 'acme' AND w.slug = 'marketing';

INSERT INTO analytics_event (workspace_id, user_id, event_name, occurred_at, source, metadata)
SELECT w.id,
       NULL,
       'api_ingest',
       now() - interval '3 days',
       'api',
       '{"status": "ok"}'::jsonb
FROM workspace w
JOIN organization o ON o.id = w.organization_id
WHERE o.slug = 'acme' AND w.slug = 'marketing';

-- Product workspace events
INSERT INTO analytics_event (workspace_id, user_id, event_name, occurred_at, source, metadata)
SELECT w.id,
       (SELECT id FROM app_user WHERE email = 'admin@example.com'),
       'page_view',
       now() - interval '1 day',
       'web',
       '{"path": "/workspaces/product"}'::jsonb
FROM workspace w
JOIN organization o ON o.id = w.organization_id
WHERE o.slug = 'acme' AND w.slug = 'product';

INSERT INTO analytics_event (workspace_id, user_id, event_name, occurred_at, source, metadata)
SELECT w.id,
       (SELECT id FROM app_user WHERE email = 'member@example.com'),
       'chart_refresh',
       now() - interval '5 days',
       'web',
       '{"chart": "TrendLine"}'::jsonb
FROM workspace w
JOIN organization o ON o.id = w.organization_id
WHERE o.slug = 'acme' AND w.slug = 'product';

INSERT INTO analytics_event (workspace_id, user_id, event_name, occurred_at, source, metadata)
SELECT w.id,
       NULL,
       'system_job',
       now() - interval '10 days',
       'system',
       '{"job": "daily_rollup"}'::jsonb
FROM workspace w
JOIN organization o ON o.id = w.organization_id
WHERE o.slug = 'acme' AND w.slug = 'product';
