-- 002_indexes.sql
-- Indexes for common query patterns. Execute statement-by-statement.

-- Workspaces by org
CREATE INDEX IF NOT EXISTS idx_workspace_org_id ON workspace (organization_id);

-- Membership lookups
CREATE INDEX IF NOT EXISTS idx_org_membership_user_id ON org_membership (user_id);

-- Analytics: the core time-series query pattern
CREATE INDEX IF NOT EXISTS idx_analytics_event_workspace_time
ON analytics_event (workspace_id, occurred_at DESC);

-- Analytics: org-scoped time queries (useful for org-level dashboards)
CREATE INDEX IF NOT EXISTS idx_analytics_event_org_time
ON analytics_event (organization_id, occurred_at DESC);

-- Analytics: event name breakdowns within a workspace + time range
CREATE INDEX IF NOT EXISTS idx_analytics_event_workspace_event_time
ON analytics_event (workspace_id, event_name, occurred_at DESC);

-- Analytics: per-user activity within workspace
CREATE INDEX IF NOT EXISTS idx_analytics_event_workspace_user_time
ON analytics_event (workspace_id, user_id, occurred_at DESC);

-- JSONB metadata index for optional filtering (use sparingly; can be heavy)
CREATE INDEX IF NOT EXISTS idx_analytics_event_metadata_gin
ON analytics_event
USING GIN (metadata);

-- Optional partial index when user_id is present (commonly used in user-scoped queries)
CREATE INDEX IF NOT EXISTS idx_analytics_event_user_time_not_null
ON analytics_event (user_id, occurred_at DESC)
WHERE user_id IS NOT NULL;
