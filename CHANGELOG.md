# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-06-18

### Added
- Initial release.
- Captures unhandled exceptions from controllers, Rack, Sidekiq and ActiveJob.
- Deduplicates errors by fingerprint.
- Kanban dashboard (and optional RailsAdmin board) to triage errors as tasks.
