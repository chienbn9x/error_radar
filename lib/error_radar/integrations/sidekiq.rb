# frozen_string_literal: true

module ErrorRadar
  module Integrations
    # Hooks ErrorRadar.capture into Sidekiq's server-side error handler so every
    # background-job failure becomes an ErrorLog task. Idempotent.
    module Sidekiq
      HANDLER = lambda do |exception, ctx, _config = nil|
        job = (ctx && ctx[:job]) || {}
        ErrorRadar.capture(
          exception,
          source: job['class'] || (ctx && ctx[:context]) || 'Sidekiq',
          context: {
            jid: job['jid'],
            queue: job['queue'],
            args: job['args'],
            retry_count: job['retry_count'],
            failed_at: job['failed_at']
          }.compact
        )
      rescue StandardError => e
        ErrorRadar::Tracking.warn_internal("Sidekiq error_handler failed: #{e.class}: #{e.message}")
      end

      def self.install!
        ::Sidekiq.configure_server do |config|
          handlers = config.error_handlers
          handlers << HANDLER unless handlers.include?(HANDLER)
        end
      rescue StandardError => e
        ErrorRadar::Tracking.warn_internal("Sidekiq integration failed: #{e.class}: #{e.message}")
      end
    end
  end
end
