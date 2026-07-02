# frozen_string_literal: true

# Configuration for the error_radar gem. All keys are optional; sensible
# defaults are shown. See https://github.com/chienbn9x/error_radar for details.
ErrorRadar.configure do |config|
  # Master switch. Turn off in environments where you don't want to persist
  # errors (e.g. test).
  config.enabled = !Rails.env.test?

  # --- Integrations (auto-detected; flip off if you don't want them) ---
  config.install_middleware  = true   # Rack: capture web-layer exceptions (auto)
  config.install_sidekiq     = true   # capture Sidekiq job failures (auto, if Sidekiq present)
  config.install_active_job  = true   # capture ActiveJob failures for any adapter (auto)
  config.install_rake        = true   # capture Rake task failures (auto)
  config.install_rails_admin = true   # register the ErrorLog board (auto, if RailsAdmin present)

  # --- Notifications ---
  # When to fire: :new_error (first occurrence of a fingerprint, default),
  #               :critical  (any critical severity, throttled to 1/hour),
  #               :all       (every occurrence, throttled to 1/hour per fingerprint)
  config.notify_on = [:new_error]

  # Slack incoming webhook (https://api.slack.com/messaging/webhooks)
  # config.slack_webhook_url = ENV['SLACK_WEBHOOK_URL']
  # config.slack_channel     = '#errors'   # optional override

  # Discord incoming webhook
  # config.discord_webhook_url = ENV['DISCORD_WEBHOOK_URL']

  # Email (requires ActionMailer to be configured in the host app)
  # config.email_recipients = ['dev@myapp.com', 'oncall@myapp.com']
  # config.email_from       = 'errors@myapp.com'

  # Generic webhook — POST JSON to any URL (PagerDuty, OpsGenie, custom scripts)
  # config.webhook_urls = [ENV['PAGERDUTY_WEBHOOK_URL']]

  # Base URL used to generate deep-links in notifications
  # config.app_host = 'https://myapp.com'
  # config.app_name = 'MyApp'              # shown in notification title/subject

  # Custom callback — runs after all built-in channels
  # config.on_error { |error_log| MyPager.create_incident(error_log) }

  # --- Dashboard access control ---
  # Run as a before_action; raise/redirect inside to deny. Example with Devise:
  # config.authenticate = ->(controller) { controller.send(:authenticate_admin!) }
  # config.current_user = ->(controller) { controller.current_admin&.email }

  # --- Custom categories (optional) ---
  # Built-in categories: application, external_api, background_job, syntax,
  # database, network. Add your own app-specific ones here. The stored integer
  # is a schema — keep it stable once you have data. Add lightly:
  # config.register_category(:instagram_api, 6)
  #
  # Or replace the whole map at once (defaults are merged in first):
  # config.categories = { instagram_api: 6, payments_api: 7 }

  # --- Custom classification ---
  # Map your own exception types to a category. First non-nil wins.
  # config.categorize { |e| :external_api if e.is_a?(MyApi::Error) }
  #
  # Pull extra columns (http_status / request_url / api_code / api_subcode) out
  # of a custom exception:
  # config.extract_details do |e|
  #   next unless e.is_a?(MyApi::Error)
  #   { http_status: e.status, request_url: e.url, api_code: e.code }
  # end

  # --- Sidekiq server health panel (optional) ---
  # Leave empty to just list whatever processes are live. To assert that
  # specific processes must always run, list them here:
  # config.expected_servers = [
  #   { key: 'web', name: 'Web', tag: 'sidekiq_web', host: 'web', queue_hint: 'low' }
  # ]

  # --- REST API ---
  # Protect /api/* endpoints with a Bearer token.
  # config.api_token = ENV['ERROR_RADAR_API_TOKEN']
  # curl -H "Authorization: Bearer $TOKEN" https://myapp.com/error_radar/api/stats

  # --- GitHub Integration ---
  # Creates GitHub issues directly from the error detail page.
  # Requires running: bin/rails generate error_radar:upgrade_v050 && bin/rails db:migrate
  # config.github_token = ENV['GITHUB_TOKEN']   # PAT with repo scope
  # config.github_repo  = 'myorg/myapp'         # "owner/repo" format

  # --- Performance & Async Capture ---
  # Write ErrorLog records via ActiveJob so exceptions don't block the request.
  # Requires ActiveJob + a queue adapter (Sidekiq, Solid Queue, etc.).
  # Falls back to synchronous capture if ActiveJob is unavailable.
  # config.async_capture     = true
  # config.capture_job_queue = :default   # queue name for CaptureJob

  # --- Retention / Cleanup ---
  # Auto-prune old resolved/ignored records to keep the table lean.
  # Run `rake error_radar:cleanup` from a cron job or Heroku Scheduler.
  # config.retention_days = 90    # delete resolved/ignored records older than 90 days
  # config.max_records    = 50000 # hard cap; oldest resolved/ignored purged first
  #
  # Rake tasks available:
  #   rake error_radar:cleanup              # apply retention_days + max_records
  #   rake error_radar:cleanup:dry_run      # preview without deleting
  #   rake error_radar:cleanup:older_than   # DAYS=30 rake error_radar:cleanup:older_than
  #   rake error_radar:stats                # print table summary
end

# ActiveJob is now captured automatically via install_active_job = true above.
# No changes needed in ApplicationJob. Set install_active_job = false if you
# only use Sidekiq and want to avoid double-counting.
