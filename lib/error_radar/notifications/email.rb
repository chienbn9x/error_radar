# frozen_string_literal: true

module ErrorRadar
  module Notifications
    # Delivers notification emails via ActionMailer (must be configured in
    # the host app). Uses deliver_later so it doesn't block the request cycle.
    module Email
      def self.deliver(log, event = :recurring)
        return unless defined?(::ActionMailer::Base)

        require 'error_radar/mailers/error_mailer'
        ErrorRadar::ErrorMailer.new_error(log, event).deliver_later
      rescue StandardError => e
        ErrorRadar::Tracking.warn_internal("Email notification failed: #{e.message}")
      end
    end
  end
end
