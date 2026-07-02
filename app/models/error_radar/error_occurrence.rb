# frozen_string_literal: true

module ErrorRadar
  # One row per individual error hit. Linked to an ErrorLog (the deduplicated
  # aggregate). Only recorded when config.track_occurrences is true and the
  # upgrade_v060 migration has been run.
  class ErrorOccurrence < ApplicationRecord
    belongs_to :error_log

    scope :recent, -> { order(occurred_at: :desc) }

    def self.record_for(log, context: {}, backtrace: nil, http_status: nil, request_url: nil)
      max = ErrorRadar.config.max_occurrences_per_error

      create!(
        error_log:   log,
        occurred_at: Time.current,
        context:     context.presence,
        backtrace:   Array(backtrace).join("\n").presence,
        http_status: http_status,
        request_url: request_url
      )

      if max&.positive?
        keep_ids = where(error_log_id: log.id).order(occurred_at: :desc).limit(max).pluck(:id)
        where(error_log_id: log.id).where.not(id: keep_ids).delete_all if keep_ids.any?
      end
    rescue ActiveRecord::StatementInvalid
      # Table not yet created — run: bin/rails generate error_radar:upgrade_v060 && bin/rails db:migrate
    rescue StandardError => e
      ErrorRadar::Tracking.warn_internal("ErrorOccurrence.record_for failed: #{e.class}: #{e.message}")
    end

    def context_pretty
      return '{}' if context.blank?
      JSON.pretty_generate(context.is_a?(Hash) ? context : JSON.parse(context.to_s))
    rescue JSON::ParserError
      context.to_s
    end
  end
end
