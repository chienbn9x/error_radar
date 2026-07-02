# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module ErrorRadar
  module Notifications
    module Discord
      SEV_COLORS = {
        'critical' => 0x7b001c,
        'error'    => 0xdc3545,
        'warning'  => 0xfd7e14,
        'info'     => 0x17a2b8
      }.freeze

      def self.deliver(log)
        url     = URI(ErrorRadar.config.discord_webhook_url)
        payload = build_payload(log)

        http              = Net::HTTP.new(url.host, url.port)
        http.use_ssl      = url.scheme == 'https'
        http.open_timeout = 5
        http.read_timeout = 5

        req                 = Net::HTTP::Post.new(url)
        req['Content-Type'] = 'application/json'
        req.body            = payload.to_json

        http.request(req)
      rescue StandardError => e
        ErrorRadar::Tracking.warn_internal("Discord notification failed: #{e.message}")
      end

      def self.build_payload(log)
        app    = ErrorRadar::Notifier.app_name
        url    = ErrorRadar::Notifier.error_url(log)
        prefix = log.new_fingerprint? ? '🆕 New error' : '🔁 Critical error'

        fields = [
          { name: 'Source',      value: (log.source || 'unknown').truncate(100), inline: true },
          { name: 'Category',    value: log.category.to_s,                       inline: true },
          { name: 'Severity',    value: log.severity.to_s,                       inline: true },
          { name: 'Occurrences', value: log.occurrences.to_s,                    inline: true }
        ]
        fields << { name: 'View', value: "[Error Radar](#{url})", inline: false } if url

        embed = {
          title:       "#{prefix}: #{log.error_class}",
          description: "```#{log.message.to_s.truncate(300)}```",
          color:       SEV_COLORS[log.severity] || 0x6c757d,
          fields:      fields,
          footer:      { text: "[#{app}] Error Radar" },
          timestamp:   log.last_seen_at&.iso8601
        }.compact

        { embeds: [embed] }
      end
    end
  end
end
