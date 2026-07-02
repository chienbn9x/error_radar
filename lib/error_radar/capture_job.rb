# frozen_string_literal: true

module ErrorRadar
  # Background job for async exception capture. Used when config.async_capture
  # is true. Failures are logged to Rails.logger and swallowed — a broken
  # capture job must not cause retry storms or affect the application.
  class CaptureJob < ActiveJob::Base
    queue_as { ErrorRadar.config.capture_job_queue }

    def perform(attrs_json)
      attrs = JSON.parse(attrs_json, symbolize_names: true)
      log   = ErrorLog.record(**attrs)
      Notifier.dispatch(log) if log
    rescue StandardError => e
      ErrorRadar::Tracking.warn_internal("CaptureJob failed: #{e.class}: #{e.message}")
    end
  end
end
