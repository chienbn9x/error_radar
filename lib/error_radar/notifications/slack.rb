# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module ErrorRadar
  module Notifications
    module Slack
      SEV_EMOJI = {
        'critical' => ':red_circle:',
        'error'    => ':large_orange_circle:',
        'warning'  => ':large_yellow_circle:',
        'info'     => ':large_blue_circle:'
      }.freeze

      def self.deliver(log)
        url     = URI(ErrorRadar.config.slack_webhook_url)
        payload = build_payload(log)

        http              = Net::HTTP.new(url.host, url.port)
        http.use_ssl      = url.scheme == 'https'
        http.open_timeout = 5
        http.read_timeout = 5

        req                  = Net::HTTP::Post.new(url)
        req['Content-Type']  = 'application/json'
        req.body             = payload.to_json

        http.request(req)
      rescue StandardError => e
        ErrorRadar::Tracking.warn_internal("Slack notification failed: #{e.message}")
      end

      def self.build_payload(log)
        emoji   = SEV_EMOJI[log.severity] || ':white_circle:'
        title   = "#{emoji} #{log.new_fingerprint? ? 'New error' : 'Critical error'}: *#{log.error_class}*"
        url     = ErrorRadar::Notifier.error_url(log)
        app     = ErrorRadar::Notifier.app_name
        channel = ErrorRadar.config.slack_channel

        blocks = [
          { type: 'section', text: { type: 'mrkdwn', text: "*[#{app}]* #{title}" } },
          {
            type: 'section',
            fields: [
              { type: 'mrkdwn', text: "*Source*\n#{(log.source || 'unknown').truncate(80)}" },
              { type: 'mrkdwn', text: "*Category*\n#{log.category}" },
              { type: 'mrkdwn', text: "*Severity*\n#{log.severity}" },
              { type: 'mrkdwn', text: "*Occurrences*\n#{log.occurrences}" }
            ]
          },
          {
            type: 'section',
            text: { type: 'mrkdwn', text: "*Message*\n```#{log.message.to_s.truncate(400)}```" }
          }
        ]

        if url
          blocks << {
            type: 'actions',
            elements: [{
              type: 'button',
              text: { type: 'plain_text', text: 'View in Error Radar', emoji: true },
              url: url
            }]
          }
        end

        payload = { blocks: blocks, text: "[#{app}] #{log.error_class}: #{log.message.to_s.truncate(200)}" }
        payload[:channel] = channel if channel.to_s != ''
        payload
      end
    end
  end
end
