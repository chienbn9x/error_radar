# frozen_string_literal: true

module ErrorRadar
  module Integrations
    # Opt-in ActiveJob capture. Include into your ApplicationJob to catch
    # exceptions from any queue adapter (not just Sidekiq), then re-raise so the
    # adapter's retry/failure handling is unaffected:
    #
    #   class ApplicationJob < ActiveJob::Base
    #     include ErrorRadar::Integrations::ActiveJob
    #   end
    #
    # NOTE: if you also enable the Sidekiq integration, Sidekiq-backed jobs will
    # be captured by both — keep only one if you want to avoid double counting.
    module ActiveJob
      extend ActiveSupport::Concern

      included do
        around_perform do |job, block|
          block.call
        rescue Exception => e # rubocop:disable Lint/RescueException
          ErrorRadar.capture(
            e,
            source: job.class.name,
            context: { args: job.arguments, job_id: job.job_id, queue: job.queue_name }
          )
          raise
        end
      end
    end
  end
end
