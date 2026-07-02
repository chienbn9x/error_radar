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
end

# ActiveJob is now captured automatically via install_active_job = true above.
# No changes needed in ApplicationJob. Set install_active_job = false if you
# only use Sidekiq and want to avoid double-counting.
