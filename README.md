# Error Radar

Drop-in error tracking & task board for Rails apps. Captures unhandled
exceptions from **controllers, Rack, Sidekiq and ActiveJob**, deduplicates them
by fingerprint (a flood of the same failure stays one task with an occurrence
count), and ships a kanban dashboard — plus an optional RailsAdmin board — to
triage them as tasks (`open → in_progress → resolved → ignored`).

It is built as a **mountable Rails Engine**, so the model, middleware, routes,
dashboard and migration all come from the gem. Everything app-specific
(authentication, custom exception types, server expectations) is injected via a
small config block.

## Requirements

- Rails `>= 7.0`, Ruby `>= 3.0`
- Optional: Sidekiq (job capture + server panel), RailsAdmin (admin board)

> Rails 8 note: the model uses the classic `enum name: {...}` form. On Rails 8
> switch it to `enum :name, {...}` (see `app/models/error_radar/error_log.rb`).

## Install

```ruby
# Gemfile
gem 'error_radar', git: 'https://github.com/chienbn9x/error_radar.git'
# or, while developing locally:
gem 'error_radar', path: '../error_radar'
```

```bash
bundle install
bin/rails generate error_radar:install   # creates initializer + migration
bin/rails db:migrate
```

Mount the dashboard:

```ruby
# config/routes.rb
authenticate :admin do                     # your own guard, optional
  mount ErrorRadar::Engine, at: '/monitoring'
end
```

Visit `/monitoring`.

## Configure

`config/initializers/error_radar.rb` (generated):

```ruby
ErrorRadar.configure do |config|
  config.enabled = !Rails.env.test?

  # Dashboard auth
  config.authenticate = ->(controller) { controller.send(:authenticate_admin!) }
  config.current_user = ->(controller) { controller.current_admin&.email }

  # Teach it about your own API error type
  config.categorize { |e| :external_api if e.is_a?(MyApi::Error) }
  config.extract_details do |e|
    { http_status: e.status, request_url: e.url, api_code: e.code } if e.is_a?(MyApi::Error)
  end
end
```

## Use

```ruby
# Capture an exception with context
ErrorRadar.capture(e, source: 'HealthController#index', context: { check: :redis })

# Log a problem without an exception
ErrorRadar.notify('Webhook signature mismatch', category: :external_api, severity: :warning)

# Wrap a boundary the middleware/Sidekiq hooks don't cover (rake tasks, cron)
ErrorRadar.monitor('NightlyReindex', context: { batch: 1 }) { do_work }
```

Web requests and Sidekiq jobs are captured automatically once installed. For
non-Sidekiq ActiveJob adapters, include the concern:

```ruby
class ApplicationJob < ActiveJob::Base
  include ErrorRadar::Integrations::ActiveJob
end
```

## What gets stored

`ErrorRadar::ErrorLog` (`error_radar_error_logs`): category, severity, status,
error_class, source, message, backtrace, JSON context, HTTP/API fields,
occurrence count, first/last seen, and resolution metadata. Identical errors
roll up by a SHA1 fingerprint of `(category, error_class, source,
normalized_message)`.

## Design notes

- **Never raises.** Every capture path rescues internally and logs to
  `Rails.logger` — error tracking must not break the code it watches.
- **Decoupled.** No host model, controller or constant is referenced directly;
  app-specifics arrive through `ErrorRadar.config`.
- **Self-contained dashboard.** Charts use Chart.js from a CDN (no `chartkick`
  dependency); the kanban uses SortableJS.
```
