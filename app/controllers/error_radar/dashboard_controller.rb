# frozen_string_literal: true

module ErrorRadar
  # Error-monitoring dashboard: summary stats, simple charts and a drag-and-drop
  # kanban board over ErrorLog statuses.
  class DashboardController < ApplicationController
    before_action :authenticate_request!

    KANBAN_LIMIT = 100
    SEVERITY_ORDER = { 'critical' => 0, 'error' => 1, 'warning' => 2, 'info' => 3 }.freeze

    def index
      @total          = ErrorLog.count
      @open_count     = ErrorLog.status_open.count
      @in_progress    = ErrorLog.status_in_progress.count
      @resolved_count = ErrorLog.status_resolved.count
      @ignored_count  = ErrorLog.status_ignored.count
      @unresolved     = @open_count + @in_progress

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
