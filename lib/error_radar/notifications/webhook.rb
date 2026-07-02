# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module ErrorRadar
  module Notifications
    # Generic outbound webhook. POSTs a JSON payload to any URL.
    # Useful for PagerDuty, OpsGenie, custom scripts, etc.
    module Webhook
      def self.deliver(log, url:, event: :recurring)
        uri = URI(url)

        http              = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl      = uri.scheme == 'https'
        http.open_timeout = 5
        http.read_timeout = 5

        req                 = Net::HTTP::Post.new(uri)
        req['Content-Type'] = 'application/json'
        req['User-Agent']   = "ErrorRadar/#{ErrorRadar::VERSION}"
        req.body            = build_payload(log, event).to_json

        http.request(req)
      rescue StandardError => e
        ErrorRadar::Tracking.warn_internal("Webhook (#{url}) notification failed: #{e.message}")
      end

      def self.build_payload(log, event)
        spike_data = log.instance_variable_get(:@spike_data)

        payload = {
          event:         event.to_s,
          app:           ErrorRadar::Notifier.app_name,
          error_class:   log.error_class,
          source:        log.source,
          category:      log.category,
          severity:      log.severity,
          message:       log.message.to_s.truncate(500),
          occurrences:   log.occurrences,
          fingerprint:   log.fingerprint,
          first_seen_at: log.first_seen_at&.iso8601,
          last_seen_at:  log.last_seen_at&.iso8601,
          url:           ErrorRadar::Notifier.error_url(log)
        }

        if spike_data
          payload[:spike] = {
            count:          spike_data[:count],
            window_minutes: spike_data[:window_minutes]
          }
        end

        payload
      end
    end
  end
end
