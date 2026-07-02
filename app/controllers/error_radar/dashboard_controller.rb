# frozen_string_literal: true

module ErrorRadar
  # Error-monitoring dashboard: summary stats, simple charts and a drag-and-drop
  # kanban board over ErrorLog statuses.
  class DashboardController < ApplicationController
    before_action :authenticate_request!

    KANBAN_LIMIT = 100
    SEVERITY_ORDER = { 'critical' => 0, 'error' => 1, 'warning' => 2, 'info' => 3 }.freeze

    def index
      counts_by_status = ErrorLog.group(:status).count
      # statuses returns {"open"=>0, "in_progress"=>1, "resolved"=>2, "ignored"=>3}
      inv = ErrorLog.statuses.invert
      @open_count     = counts_by_status[ErrorLog.statuses['open']] || 0
      @in_progress    = counts_by_status[ErrorLog.statuses['in_progress']] || 0
      @resolved_count = counts_by_status[ErrorLog.statuses['resolved']] || 0
      @ignored_count  = counts_by_status[ErrorLog.statuses['ignored']] || 0
      @total          = counts_by_status.values.sum
      @unresolved     = @open_count + @in_progress

      @oldest_record  = ErrorLog.minimum(:first_seen_at)

      @by_category = ErrorLog.unresolved.group(:category).count
      @by_severity = ErrorLog.unresolved.group(:severity).count

      # Distinct error-tasks last seen per day (last 30 days), grouped in Ruby to
      # avoid relying on DB named-timezone tables.
      @trend = ErrorLog.where(last_seen_at: 30.days.ago..)
                       .pluck(:last_seen_at)
                       .group_by { |t| t.in_time_zone.to_date }
                       .transform_values(&:size)
                       .sort.to_h
                       .transform_keys { |d| d.strftime('%m/%d') }

      @top = ErrorLog.unresolved.order(occurrences: :desc).limit(10)

      monitor = ErrorRadar::ServerMonitor.new
      @servers = monitor.statuses
      @unexpected = monitor.unexpected_processes

      @columns = ErrorLog.statuses.keys.index_with do |status|
        ErrorLog.where(status: ErrorLog.statuses[status])
                .order(last_seen_at: :desc)
                .limit(KANBAN_LIMIT)
                .to_a
                .sort_by { |e| [SEVERITY_ORDER.fetch(e.severity, 9), -e.last_seen_at.to_i] }
      end

      @external_links = build_external_links
    end

    def purge
      days    = params[:days].presence&.to_i
      dry_run = params[:dry_run] == '1'

      result = ErrorRadar::Cleanup.run(
        older_than_days: (days if days&.positive?),
        dry_run: dry_run
      )

      respond_to do |format|
        format.json { render json: result }
        format.html do
          msg = if dry_run
                  "Dry run: would delete #{result[:deleted]} record(s)."
                else
                  "Purged #{result[:deleted]} record(s)."
                end
          redirect_to root_path, notice: msg
        end
      end
    end

    private

    def build_external_links
      links = {}
      if defined?(::RailsAdmin)
        links[:rails_admin] = (rails_admin.index_path(model_name: 'error_radar~error_log') rescue nil)
      end
      links[:sidekiq] = '/sidekiq' if defined?(::Sidekiq::Web)
      links.compact
    end
  end
end
