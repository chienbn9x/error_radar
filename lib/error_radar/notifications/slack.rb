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

      def self.deliver(log, event = :recurring)
        url = URI(ErrorRadar.config.slack_webhook_url)

        http              = Net::HTTP.new(url.host, url.port)
        http.use_ssl      = url.scheme == 'https'
        http.open_timeout = 5
        http.read_timeout = 5

        req                 = Net::HTTP::Post.new(url)
        req['Content-Type'] = 'application/json'
        req.body            = build_payload(log, event).to_json

        http.request(req)
      rescue StandardError => e
        ErrorRadar::Tracking.warn_internal("Slack notification failed: #{e.message}")
      end

      def self.build_payload(log, event)
        spike_data = log.instance_variable_get(:@spike_data)
        app        = ErrorRadar::Notifier.app_name
        link       = ErrorRadar::Notifier.error_url(log)
        channel    = ErrorRadar.config.slack_channel

        emoji, title = case event
                       when :spike
                         [':warning:', "Spike — #{spike_data[:count]} hits in #{spike_data[:window_minutes]} min: *#{log.error_class}*"]
                       when :new_error
                         [SEV_EMOJI[log.severity] || ':white_circle:', "New error: *#{log.error_class}*"]
                       else
                         [SEV_EMOJI[log.severity] || ':white_circle:', "#{log.severity.capitalize} error: *#{log.error_class}*"]
                       end

        blocks = [
          { type: 'section', text: { type: 'mrkdwn', text: "#{emoji} *[#{app}]* #{title}" } },
          {
            type: 'section',
            fields: [
              { type: 'mrkdwn', text: "*Source*\n#{(log.source || 'unknown').truncate(80)}" },
              { type: 'mrkdwn', text: "*Category*\n#{log.category}" },
              { type: 'mrkdwn', text: "*Severity*\n#{log.severity}" },
              { type: 'mrkdwn', text: "*Total occurrences*\n#{log.occurrences}" }
            ]
          },
          {
            type: 'section',
            text: { type: 'mrkdwn', text: "*Message*\n```#{log.message.to_s.truncate(400)}```" }
          }
        ]

        if link
          blocks << {
            type: 'actions',
            elements: [{
              type: 'button',
              text:  { type: 'plain_text', text: 'View in Error Radar', emoji: true },
              url:   link,
              style: event == :spike ? 'danger' : 'primary'
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
