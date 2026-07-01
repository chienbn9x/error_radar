# Changelog

All notable changes to this project will be documented in this file.

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
