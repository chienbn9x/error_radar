# frozen_string_literal: true

module ErrorRadar
  module Api
    # GET /api/stats — summary counts for dashboards, CI gates, uptime monitors.
    class StatsController < BaseController
      def show
        render json: {
          total:       ErrorLog.count,
          open:        ErrorLog.status_open.count,
          in_progress: ErrorLog.status_in_progress.count,
          resolved:    ErrorLog.status_resolved.count,
          ignored:     ErrorLog.status_ignored.count,
          unresolved:  ErrorLog.unresolved.count,
          by_severity: ErrorLog.group(:severity).count,
          by_category: ErrorLog.group(:category).count,
          generated_at: Time.current.iso8601
        }
      end
    end
  end
end
