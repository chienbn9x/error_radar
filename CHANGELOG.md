# Changelog

All notable changes to this project will be documented in this file.

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
