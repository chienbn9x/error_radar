# frozen_string_literal: true

module ErrorRadar
  # Dispatches alert notifications (Slack, Discord, email, webhooks, custom
  # callbacks) after an ErrorLog is persisted. Called from Tracking.capture and
  # Tracking.notify. Never raises — a broken notification must not affect the
  # host application.
  module Notifier
    THROTTLE_MUTEX = Mutex.new
    # fingerprint => Time of last notification (in-memory, resets on restart)
    THROTTLE = {}
    THROTTLE_INTERVAL = 3600 # seconds between repeat alerts per fingerprint

    def self.dispatch(log)
      return unless ErrorRadar.config.enabled
      return unless should_fire?(log)

      cfg = ErrorRadar.config
      send_slack(log)                           if cfg.slack_webhook_url.to_s.start_with?('http')
      send_discord(log)                         if cfg.discord_webhook_url.to_s.start_with?('http')
      send_email(log)                           if cfg.email_recipients.any?
      cfg.webhook_urls.each { |url| send_webhook(log, url) }
      cfg.error_callbacks.each { |cb| safe_call(cb, log) }
    rescue StandardError => e
      ErrorRadar::Tracking.warn_internal("Notifier.dispatch failed: #{e.message}")
    end

    # ── Fire decision ──────────────────────────────────────────────────────
    def self.should_fire?(log)
      rules = Array(ErrorRadar.config.notify_on).map(&:to_sym)
      return false if rules.empty?

      # :new_error — fire exactly once per fingerprint (no throttle needed)
      return true if rules.include?(:new_error) && log.new_fingerprint?

      # :critical / :all — fire for recurring events, subject to throttle
      matches_severity = rules.include?(:all) ||
                         (rules.include?(:critical) && log.severity_critical?)
      matches_severity && throttle_ok?(log.fingerprint)
    end

    def self.throttle_ok?(fingerprint)
      THROTTLE_MUTEX.synchronize do
        last = THROTTLE[fingerprint]
        ok   = last.nil? || (Time.current - last) >= THROTTLE_INTERVAL
        THROTTLE[fingerprint] = Time.current if ok
        ok
      end
    end

    # ── Channel dispatchers ────────────────────────────────────────────────
    def self.send_slack(log)
      require 'error_radar/notifications/slack'
      Notifications::Slack.deliver(log)
    end

    def self.send_discord(log)
      require 'error_radar/notifications/discord'
      Notifications::Discord.deliver(log)
    end

    def self.send_email(log)
      require 'error_radar/notifications/email'
      Notifications::Email.deliver(log)
    end

    def self.send_webhook(log, url)
      require 'error_radar/notifications/webhook'
      Notifications::Webhook.deliver(log, url: url)
    end

    def self.safe_call(cb, log)
      cb.call(log)
    rescue StandardError => e
      ErrorRadar::Tracking.warn_internal("on_error callback failed: #{e.message}")
    end

    # Build a deep-link URL to the error detail page.
    def self.error_url(log)
      host = ErrorRadar.config.app_host.to_s.chomp('/')
      return nil if host.empty?

      "#{host}/error_radar/errors/#{log.id}"
    end

    def self.app_name
      ErrorRadar.config.app_name ||
        (defined?(Rails) && Rails.application ? Rails.application.class.module_parent_name : 'App')
    end
  end
end
