# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-07-03

### Added
- **Error assignment**: assign any error to a team member from the detail page.
  Stored in the new `assigned_to` column on `error_radar_error_logs`.
- **Comment thread**: add, view, and delete comments on each error. Comments
  are stored in the new `error_radar_comments` table with `author` and `body`.
- **Activity log**: every status change, assignment, and comment is recorded in
  `error_radar_activities` (columns: `actor`, `action`, `detail`, `created_at`).
  The timeline is shown on the error detail page (last 50 events).
- **`error_radar:upgrade_v100` generator**: one migration that adds `assigned_to`
  to `error_radar_error_logs` and creates both `error_radar_comments` and
  `error_radar_activities` tables.
- **`PATCH /errors/:id/assign`**: JSON endpoint to assign/unassign an error.
- **`POST /errors/:id/comments`**: JSON endpoint to add a comment.
- **`DELETE /errors/:id/comments/:cid`**: JSON endpoint to remove a comment.
- **`ErrorRadar::ErrorActivity`** model with `icon` helper mapping action names
  to display glyphs (✓ resolved, ↩ reopened, 💬 commented, → assigned, …).
- **`ErrorRadar::ErrorComment`** model with `chronological` scope.
- All new features are **backward-compatible** — existing apps without the
  migration see a panel with the migration command to run.

### Notes
- Activity logging is best-effort: if the activities table does not exist yet,
  the action still succeeds and the log write is silently skipped.
- The `current_user` proc (`config.current_user`) is used as the default actor;
  clients can also pass `author` in the comment POST body.

## [0.9.0] - 2026-07-03

### Added
- **Digest email**: a periodic summary email (HTML + plain text) with:
  - Summary row: new errors, open + in progress, resolved this period, total in DB
  - Unresolved-by-severity bar chart (inline table)
  - Top 10 unresolved errors (linked to detail page when `app_host` is set)
  - New errors first seen in the period
  - Unresolved-by-category breakdown
  - "Open Error Radar →" button
- **`config.digest_enabled`** (default: `false`) — gates delivery; set `true`
  then schedule the rake task.
- **`config.digest_recipients`** — separate recipient list for digests; falls
  back to `config.email_recipients` if empty.
- **`ErrorRadar::Digest.deliver`** — programmatic delivery:
  `ErrorRadar::Digest.deliver(since: 24.hours.ago, period: :daily)`
- **Rake tasks**:
  - `rake error_radar:digest` — last 24 hours (daily digest)
  - `rake error_radar:digest:weekly` — last 7 days (weekly digest)
  - Both accept `SINCE="2024-01-01 08:00"` env override for custom windows
- **`DigestMailer`** (`app/mailers/error_radar/digest_mailer.rb`) —
  ActionMailer class with HTML + text templates.

### Notes
- Requires ActionMailer configured in the host app (same requirement as the
  existing `new_error` notification email).
- Scheduling is left to the host app's cron/scheduler — no in-process scheduler
  dependency. Heroku Scheduler, whenever, clockwork, solid-cron all work.
- Subject line: `[App] Daily Digest — N new · N open · N resolved`

## [0.8.0] - 2026-07-03

### Added
- **Rate-based spike alerts**: add `:spike` to `config.notify_on` to fire a
  notification when a single error exceeds `config.spike_threshold` (default: 10)
  occurrences within `config.spike_window_minutes` (default: 5). Re-alerts once
  per window after the first trigger.
- **`ErrorRadar::SpikeDetector`**: detects spikes using two strategies — if
  `track_occurrences` is enabled it queries `error_radar_occurrences` for an
  exact cross-process count; otherwise falls back to an in-memory ring buffer
  (per-process, resets on restart). Memory is capped at 1 000 timestamps per
  fingerprint.
- **`config.spike_threshold`** (default: 10) and **`config.spike_window_minutes`**
  (default: 5) — tune the spike trigger.
- **Spike throttle**: a spike alert re-fires at most once per window
  (e.g. every 5 minutes), using a separate throttle key from `:critical`/`:all`.
- **Event-aware notification channels**: all channels (Slack, Discord, email,
  webhook) now receive the notification event (`:new_error`, `:spike`,
  `:recurring`) and format accordingly:
  - Slack: `:warning:` emoji, "danger" button colour, hit-count in title
  - Discord: orange embed colour (`#ff6600`) for spikes
  - Email subject: `[App] SPIKE ErrorClass: N hits in M min`
  - Webhook payload: `event: "spike"` + `spike: { count:, window_minutes: }`

### Changed
- `Notifier.dispatch` now determines a single *event type* before dispatching,
  preventing a log from matching both `:spike` and `:critical` simultaneously.
- All channel `deliver` methods accept an optional `event` argument (default
  `:recurring`) — backwards-compatible if called directly.

## [0.7.0] - 2026-07-03

### Added
- **Occurrence history**: every individual error hit can now be stored in a
  separate `error_radar_occurrences` table. Enable with
  `config.track_occurrences = true` after running the upgrade migration:
  `bin/rails generate error_radar:upgrade_v060 && bin/rails db:migrate`.
- **`ErrorRadar::ErrorOccurrence` model**: columns `occurred_at`, `context`,
  `backtrace`, `http_status`, `request_url`. Belongs to `ErrorLog` via
  `error_log_id`. Indexed on `(error_log_id, occurred_at)` for fast retrieval.
- **`config.max_occurrences_per_error`** (default: 200): automatically prunes
  the oldest occurrences for a given error on each new hit so the table stays
  bounded without manual cleanup.
- **Occurrences panel on error detail page**: shows the 20 most recent
  occurrences with timestamp, HTTP status badge, request URL, and expandable
  "Context" / "Stack" toggles. Paginated at 20 per page.
- **`GET /api/errors/:id`** now includes `recent_occurrences` (last 10 hits
  with `occurred_at`, `http_status`, `request_url`, `context`) when
  `track_occurrences` is enabled.
- **`error_radar:upgrade_v060` generator**: generates the migration that creates
  `error_radar_occurrences`.
- **`ErrorLog#occurrences`** association: `has_many :occurrences, dependent: :delete_all`
  so destroying an error log also removes its occurrence history.

### Notes
- `track_occurrences` defaults to `false` to avoid unexpected writes before the
  migration is run. Set it to `true` after the migration has been applied.
- Occurrences are recorded via `ErrorLog.record`, which is called by both the
  synchronous capture path and `CaptureJob` (async path) — no extra
  configuration needed once enabled.

## [0.6.0] - 2026-07-03

### Added
- **Async capture** via ActiveJob: set `config.async_capture = true` to enqueue
  error writes through `CaptureJob` so exceptions don't block the request/job
  thread. Falls back to synchronous capture if ActiveJob is unavailable.
  Configure the queue with `config.capture_job_queue` (default `:default`).
- **Age-based retention**: set `config.retention_days` to automatically prune
  resolved/ignored records older than N days.
- **Count-based retention**: set `config.max_records` to cap the table size;
  oldest resolved/ignored records are deleted first when the limit is exceeded.
- **`ErrorRadar::Cleanup.run`**: underlying cleanup logic, callable from Ruby or
  Rake. Supports `older_than_days:` override and `dry_run: true` for previewing
  without deleting.
- **Rake tasks**:
  - `rake error_radar:cleanup` — apply `retention_days` + `max_records`
  - `rake error_radar:cleanup:dry_run` — preview without deleting
  - `rake error_radar:cleanup:older_than` — one-off: `DAYS=30 rake …`
  - `rake error_radar:stats` — print table summary (total, by status, oldest)
- **Dashboard maintenance panel**: data summary (total / purgeable / open),
  oldest record date, and an inline "Purge / Dry run" form with adjustable days.
- **`POST /maintenance/purge`** endpoint: called by the dashboard's Purge button;
  accepts `days` and `dry_run` params, returns JSON `{ deleted:, dry_run: }`.
- **Dashboard stat query optimization**: 5 separate COUNT queries replaced by one
  `group(:status).count` query.

### Notes
- `async_capture` is `false` by default to avoid surprising behaviour for apps
  that do not have a queue adapter configured.
- Cleanup only touches `resolved` and `ignored` records — open/in-progress
  records are never auto-deleted.

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
