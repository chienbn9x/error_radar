# Changelog

All notable changes to this project will be documented in this file.

## [0.5.0] - 2026-07-03

### Added
- **REST API** at `/api/*` for external integrations (CI/CD, dashboards, scripts):
  - `GET  /api/errors` — paginated list with the same filters as the web UI
    (`status`, `severity`, `category`, `q`, `from`, `to`, `sort`, `order`, `page`)
  - `GET  /api/errors/:id` — full detail including context, backtrace, and
    `github_issue_url` (if column is present)
  - `PATCH /api/errors/:id` — update status; resolve accepts optional `note`
    and `resolved_by` params
  - `GET  /api/stats` — summary counts by status, severity, and category
- **Bearer-token API auth**: set `config.api_token` to protect all `/api/*`
  endpoints with `Authorization: Bearer <token>`.
- **GitHub Issue integration**: "Create GitHub Issue" button on the error detail
  page opens a pre-filled issue with error class, source, message, backtrace,
  and a deep-link back to Error Radar. Requires `config.github_token` and
  `config.github_repo`.
- **`github_issue_url` column**: stored on the error row so the button becomes
  "View GitHub Issue" once an issue exists. Requires running the upgrade
  migration: `bin/rails generate error_radar:upgrade_v050 && bin/rails db:migrate`.
- **`error_radar:upgrade_v050` generator**: generates the migration that adds
  `github_issue_url` to `error_radar_error_logs`.

### Notes
- The GitHub column is optional — the integration is gracefully degraded when the
  migration has not been run (button appears but URL is not persisted).
- The API controllers live in `ErrorRadar::Api::*` to avoid polluting the host
  app's controller namespace.

## [0.4.0] - 2026-07-03

### Added
- **Slack notifications**: sends a Block Kit message with error details and a
  deep-link button. Configure with `config.slack_webhook_url` and optional
  `config.slack_channel`.
- **Discord notifications**: sends a rich embed to any Discord webhook.
  Configure with `config.discord_webhook_url`.
- **Email notifications**: delivers an HTML + plain-text email via ActionMailer.
  Configure `config.email_recipients` and `config.email_from`.
- **Generic webhook**: POSTs a JSON payload to any URL (PagerDuty, OpsGenie,
  custom scripts). Configure with `config.webhook_urls = [url1, url2]`.
- **Custom callbacks**: `config.on_error { |log| ... }` for arbitrary alerting
  logic (e.g. PagerDuty SDK, Telegram, SMS).
- **`notify_on` rule set**: controls when alerts fire — `:new_error` (default,
  first occurrence per fingerprint), `:critical` (any critical severity, 1/hour
  throttle), `:all` (every occurrence, 1/hour throttle per fingerprint).
- **In-memory throttle**: prevents notification storms for `:critical` and `:all`
  rules — at most one alert per fingerprint per hour.
- **Deep-links in notifications**: set `config.app_host` to include a link to
  the error detail page in every notification.
- **`ErrorLog#new_fingerprint?`**: transient predicate (not persisted) that is
  `true` when the record was just created for the first time.

## [0.3.0] - 2026-07-03

### Added
- **Zero-config auto-capture for ActiveJob**: any ActiveJob subclass (regardless
  of queue adapter) now has exceptions captured automatically via
  `ActiveSupport.on_load(:active_job)`. No need to include the module manually.
  Disable with `config.install_active_job = false` (e.g. when using Sidekiq only).
- **Zero-config auto-capture for Rake tasks**: patches `Rake::Task#execute` so
  every task failure is recorded automatically. Disable with
  `config.install_rake = false`.
- **Full error list page** at `/errors` with pagination (50 per page),
  full-text search (message / error class / source), filter by status /
  severity / category / date range, sortable columns, and bulk actions
  (resolve / ignore / reopen / delete).
- **Bulk actions**: select individual rows or all rows, then resolve, ignore,
  reopen, or delete in one click.
- **Quick-action buttons** on the list (✓ resolve, ✕ ignore) without leaving
  the page.
- **Improved error detail page**: context and backtrace displayed side-by-side,
  inline resolution note field, delete button with confirmation.
- **Navigation bar** across all dashboard pages linking Dashboard ↔ All Errors.

### Changed
- `show` and `update_status` actions moved from `DashboardController` to the
  new `ErrorsController`; route paths (`/errors/:id` etc.) are unchanged.
- Dashboard index h1 changed from "🛰 Error Radar" to "Dashboard" (branding
  now lives in the shared nav bar).

## [0.2.0] - 2026-07-02

### Added
- Host-configurable error categories. The `category` enum is no longer fixed:
  register app-specific categories with `config.register_category(:name, int)`
  or replace the map with `config.categories = {...}` (built-in defaults are
  merged in first). Stored integers are treated as a schema and must stay
  stable once data exists.

### Notes
- Backward compatible: with no configuration the six built-in categories
  (`application`, `external_api`, `background_job`, `syntax`, `database`,
  `network`) behave exactly as in 0.1.0.

## [0.1.0] - 2026-06-18

### Added
- Initial release.
- Captures unhandled exceptions from controllers, Rack, Sidekiq and ActiveJob.
- Deduplicates errors by fingerprint.
- Kanban dashboard (and optional RailsAdmin board) to triage errors as tasks.
