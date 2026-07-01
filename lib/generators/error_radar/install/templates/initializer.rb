# frozen_string_literal: true

# Configuration for the error_radar gem. All keys are optional; sensible
# defaults are shown. See https://github.com/chienbn9x/error_radar for details.
ErrorRadar.configure do |config|
  # Master switch. Turn off in environments where you don't want to persist
  # errors (e.g. test).
  config.enabled = !Rails.env.test?

  # --- Integrations (auto-detected; flip off if you don't want them) ---
  config.install_middleware  = true   # Rack: capture web-layer exceptions
  config.install_sidekiq     = true   # capture Sidekiq job failures (if Sidekiq present)
  config.install_rails_admin = true   # register the ErrorLog board (if RailsAdmin present)

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

# --- Optional: capture ActiveJob failures across ALL queue adapters ---
# Add to app/jobs/application_job.rb (skip if you only use Sidekiq, since the
# Sidekiq integration above already covers it):
#
#   class ApplicationJob < ActiveJob::Base
#     include ErrorRadar::Integrations::ActiveJob
#   end
