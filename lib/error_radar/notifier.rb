# frozen_string_literal: true

module ErrorRadar
  # Dispatches alert notifications (Slack, Discord, email, webhooks, custom
  # callbacks) after an ErrorLog is persisted. Called from Tracking.capture and
  # Tracking.notify. Never raises — a broken notification must not affect the
  # host application.
  #
  # Notification events:
  #   :new_error  — first time a fingerprint is seen (no throttle)
  #   :spike      — error rate exceeds config.spike_threshold in the window
  #   :recurring  — matches :critical or :all rule, throttled to 1/hour
  module Notifier
    THROTTLE_MUTEX    = Mutex.new
    # key => Time of last notification (in-memory, resets on restart)
    # Keys: fingerprint (for :recurring) or "spike:fingerprint" (for :spike)
    THROTTLE          = {}
    THROTTLE_INTERVAL = 3600 # seconds between repeat alerts per fingerprint

    def self.dispatch(log)
      return unless ErrorRadar.config.enabled

      rules = Array(ErrorRadar.config.notify_on).map(&:to_sym)
      return if rules.empty?

      # Record the hit for in-memory spike tracking before we test the count.
      if rules.include?(:spike)
        require 'error_radar/spike_detector'
        SpikeDetector.record_hit(log.fingerprint)
      end

      event = determine_event(log, rules)
      return unless event

      fire_all(log, event)
    rescue StandardError => e
      ErrorRadar::Tracking.warn_internal("Notifier.dispatch failed: #{e.message}")
    end

    # ── Fire decision ──────────────────────────────────────────────────────

    def self.determine_event(log, rules)
      # :new_error fires exactly once per fingerprint, no throttle
      return :new_error if rules.include?(:new_error) && log.new_fingerprint?

      # :spike — rate-based alert when occurrences in window exceed threshold
      if rules.include?(:spike)
        spike_count = SpikeDetector.check(log)
        if spike_count
          window_secs = ErrorRadar.config.spike_window_minutes * 60
          if throttle_ok?("spike:#{log.fingerprint}", window_secs)
            log.instance_variable_set(:@spike_data, {
              count:          spike_count,
              window_minutes: ErrorRadar.config.spike_window_minutes
            })
            return :spike
          end
        end
      end

      # :critical / :all — throttled recurring alerts
      matches = rules.include?(:all) ||
                (rules.include?(:critical) && log.severity_critical?)
      return :recurring if matches && throttle_ok?(log.fingerprint, THROTTLE_INTERVAL)

      nil
    end

    def self.throttle_ok?(key, interval = THROTTLE_INTERVAL)
      THROTTLE_MUTEX.synchronize do
        last = THROTTLE[key]
        ok   = last.nil? || (Time.current - last) >= interval
        THROTTLE[key] = Time.current if ok
        ok
      end
    end

    # ── Channel dispatchers ────────────────────────────────────────────────

    def self.fire_all(log, event)
      cfg = ErrorRadar.config
      send_slack(log, event)                     if cfg.slack_webhook_url.to_s.start_with?('http')
      send_discord(log, event)                   if cfg.discord_webhook_url.to_s.start_with?('http')
      send_email(log, event)                     if cfg.email_recipients.any?
      cfg.webhook_urls.each { |url| send_webhook(log, url, event) }
      cfg.error_callbacks.each { |cb| safe_call(cb, log) }
    end

    def self.send_slack(log, event)
      require 'error_radar/notifications/slack'
      Notifications::Slack.deliver(log, event)
    end

    def self.send_discord(log, event)
      require 'error_radar/notifications/discord'
      Notifications::Discord.deliver(log, event)
    end

    def self.send_email(log, event)
      require 'error_radar/notifications/email'
      Notifications::Email.deliver(log, event)
    end

    def self.send_webhook(log, url, event)
      require 'error_radar/notifications/webhook'
      Notifications::Webhook.deliver(log, url: url, event: event)
    end

    def self.safe_call(cb, log)
      cb.call(log)
    rescue StandardError => e
      ErrorRadar::Tracking.warn_internal("on_error callback failed: #{e.message}")
    end

    # ── Helpers ───────────────────────────────────────────────────────────

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
