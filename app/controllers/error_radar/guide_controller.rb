# frozen_string_literal: true

module ErrorRadar
  class GuideController < ApplicationController
    before_action :authenticate_request!

    def index
      cfg = ErrorRadar.config

      @sections = {
        auto_capture: {
          middleware:   cfg.install_middleware,
          active_job:   cfg.install_active_job,
          sidekiq:      cfg.install_sidekiq && defined?(::Sidekiq),
          rake:         cfg.install_rake,
          rails_admin:  cfg.install_rails_admin && defined?(::RailsAdmin)
        },
        notifications: {
          slack:         cfg.slack_webhook_url.to_s.start_with?('http'),
          discord:       cfg.discord_webhook_url.to_s.start_with?('http'),
          email:         cfg.email_recipients.any?,
          webhooks:      cfg.webhook_urls.any?,
          callbacks:     cfg.error_callbacks.any?,
          spike_alerts:  Array(cfg.notify_on).map(&:to_sym).include?(:spike),
          notify_on:     Array(cfg.notify_on).map(&:to_s).join(', ')
        },
        api: {
          rest_api:     true,
          api_secured:  cfg.api_token.present?,
          github:       cfg.github_token.present? && cfg.github_repo.present?,
          github_repo:  cfg.github_repo
        },
        performance: {
          async_capture:      cfg.async_capture,
          occurrence_tracking: cfg.track_occurrences,
          retention_days:      cfg.retention_days,
          max_records:         cfg.max_records
        },
        team: {
          digest:      cfg.digest_enabled,
          v100_migrated: begin
                           ErrorLog.column_names.include?('assigned_to')
                         rescue StandardError
                           false
                         end
        }
      }
    end
  end
end
