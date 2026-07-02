# frozen_string_literal: true

module ErrorRadar
  # Gathers error statistics for a time window and delivers a digest email.
  # Intended to be called from a cron job or scheduled task:
  #
  #   # Daily (runs every morning via cron / Heroku Scheduler):
  #   rake error_radar:digest
  #
  #   # Weekly:
  #   rake error_radar:digest:weekly
  #
  #   # From code:
  #   ErrorRadar::Digest.deliver(since: 24.hours.ago, period: :daily)
  module Digest
    def self.deliver(since: nil, period: :daily)
      return unless ErrorRadar.config.digest_enabled

      since ||= period == :weekly ? 7.days.ago : 24.hours.ago
      data    = build(since: since)

      require 'error_radar/mailers/digest_mailer'
      DigestMailer.digest(data, period: period).deliver_now
    rescue StandardError => e
      ErrorRadar::Tracking.warn_internal("Digest.deliver failed: #{e.class}: #{e.message}")
    end

    def self.build(since:)
      now           = Time.current
      counts        = ErrorLog.group(:status).count
      inv           = ErrorLog.statuses.invert

      open_count    = counts[ErrorLog.statuses['open']]        || 0
      in_prog_count = counts[ErrorLog.statuses['in_progress']] || 0
      resolved      = counts[ErrorLog.statuses['resolved']]    || 0
      ignored       = counts[ErrorLog.statuses['ignored']]     || 0
      total         = counts.values.sum
      unresolved    = open_count + in_prog_count

      new_this_period      = ErrorLog.where('first_seen_at >= ?', since).count
      resolved_this_period = ErrorLog.where('resolved_at >= ?', since).count
      reopened_this_period = ErrorLog.unresolved.where('resolved_at < ?', since)
                                     .where('last_seen_at >= ?', since).count

      top_unresolved = ErrorLog.unresolved.order(occurrences: :desc).limit(10).to_a
      recent_new     = ErrorLog.where('first_seen_at >= ?', since)
                               .order(first_seen_at: :desc).limit(10).to_a

      by_severity  = ErrorLog.unresolved.group(:severity).count
                             .transform_keys { |k| ErrorLog.severities.invert[k] || k.to_s }
      by_category  = ErrorLog.unresolved.group(:category).count
                             .transform_keys { |k| ErrorLog.categories.invert[k] || k.to_s }

      trend = build_trend(since, now)

      {
        period_start:         since,
        period_end:           now,
        total:                total,
        open:                 open_count,
        in_progress:          in_prog_count,
        unresolved:           unresolved,
        resolved_total:       resolved,
        ignored_total:        ignored,
        new_this_period:      new_this_period,
        resolved_this_period: resolved_this_period,
        reopened_this_period: reopened_this_period,
        top_unresolved:       top_unresolved,
        recent_new:           recent_new,
        by_severity:          by_severity,
        by_category:          by_category,
        trend:                trend
      }
    end

    def self.build_trend(since, now)
      days = [((now - since) / 86_400).ceil, 30].min
      ErrorLog.where(last_seen_at: days.days.ago..)
              .pluck(:last_seen_at)
              .group_by { |t| t.to_date }
              .transform_values(&:size)
              .sort.to_h
              .transform_keys { |d| d.strftime('%m/%d') }
    end
    private_class_method :build_trend
  end
end
