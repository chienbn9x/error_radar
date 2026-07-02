# frozen_string_literal: true

require 'digest'

module ErrorRadar
  # One row per distinct failure (collapsed by fingerprint). Doubles as a task
  # on the triage board. Table: error_radar_error_logs.
  class ErrorLog < ApplicationRecord
    # Category map is host-configurable (built-in defaults + anything the app
    # registers via ErrorRadar.config). Read at class-load, which happens after
    # the host's initializer has run `ErrorRadar.configure`, so custom
    # categories are already merged in. See ErrorRadar::Configuration.
    enum category: ErrorRadar.config.categories, _prefix: :category

    enum severity: { info: 0, warning: 1, error: 2, critical: 3 }, _prefix: :severity

    enum status: { open: 0, in_progress: 1, resolved: 2, ignored: 3 }, _prefix: :status

    has_many :error_occurrences, class_name: 'ErrorRadar::ErrorOccurrence',
                                foreign_key: :error_log_id,
                                dependent: :delete_all

    has_many :comments,   class_name: 'ErrorRadar::ErrorComment',
                          foreign_key: :error_log_id,
                          dependent: :delete_all

    has_many :activities, class_name: 'ErrorRadar::ErrorActivity',
                          foreign_key: :error_log_id,
                          dependent: :delete_all

    validates :fingerprint, presence: true, uniqueness: true
    validates :first_seen_at, :last_seen_at, presence: true

    scope :open,        -> { where(status: statuses[:open]) }
    scope :in_progress, -> { where(status: statuses[:in_progress]) }
    scope :resolved,    -> { where(status: statuses[:resolved]) }
    scope :ignored,     -> { where(status: statuses[:ignored]) }
    scope :unresolved,  -> { where(status: [statuses[:open], statuses[:in_progress]]) }
    scope :recent,      -> { order(last_seen_at: :desc) }

    # Record (or roll-up) an error. Idempotent per fingerprint: identical errors
    # increment `occurrences` and bump `last_seen_at` instead of creating a new
    # row. NEVER raises — logging must not break the calling code path.
    def new_fingerprint?
      @new_fingerprint || false
    end

    def self.record(category:, message:, severity: :error, error_class: nil, source: nil,
                    backtrace: nil, context: {}, http_status: nil, request_url: nil,
                    api_code: nil, api_subcode: nil, fingerprint: nil)
      now = Time.current
      fp  = presence(fingerprint) || build_fingerprint(category: category, error_class: error_class, source: source, message: message)

      log             = find_or_initialize_by(fingerprint: fp)
      new_fingerprint = !log.persisted?

      if log.persisted?
        log.occurrences += 1
        log.status = :open if log.status_resolved? || log.status_ignored?
      else
        log.assign_attributes(
          category: category, severity: severity, error_class: error_class, source: source,
          http_status: http_status, request_url: request_url, api_code: api_code, api_subcode: api_subcode,
          first_seen_at: now, status: :open
        )
      end

      log.message      = message.to_s.truncate(ErrorRadar.config.max_message_length)
      log.backtrace    = presence(Array(backtrace).join("\n")) || log.backtrace
      log.context      = (log.context || {}).merge(context.presence || {}).deep_stringify_keys if context.present? || log.context
      log.severity     = severity if log.new_record? || severity_rank(severity) > severity_rank(log.severity)
      log.last_seen_at = now
      log.save!
      log.instance_variable_set(:@new_fingerprint, new_fingerprint)

      if ErrorRadar.config.track_occurrences
        ErrorRadar::ErrorOccurrence.record_for(
          log,
          context:     context,
          backtrace:   backtrace,
          http_status: http_status,
          request_url: request_url
        )
      end

      log
    rescue StandardError => e
      ErrorRadar::Tracking.warn_internal("ErrorLog.record failed: #{e.class}: #{e.message}")
      nil
    end

    def self.build_fingerprint(category:, error_class:, source:, message:)
      normalized = message.to_s
                          .gsub(/\d+/, '#')                        # ids, counts, timestamps
                          .gsub(/0x[0-9a-f]+/i, '0x#')             # object addresses
                          .gsub(/[0-9a-f]{8}-[0-9a-f-]{27}/i, '#') # uuids
                          .strip
      Digest::SHA1.hexdigest([category, error_class, source, normalized].join('|'))
    end

    def self.severity_rank(value)
      severities[value.to_s] || 0
    end

    def self.presence(value)
      value.respond_to?(:empty?) ? (value.empty? ? nil : value) : value
    end

    def short_message
      message.to_s.truncate(120)
    end

    def resolve!(by: nil, note: nil)
      update!(status: :resolved, resolved_at: Time.current, resolved_by: by, resolution_note: note.presence || resolution_note)
    end

    def reopen!
      update!(status: :open, resolved_at: nil)
    end
  end
end
