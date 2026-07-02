# frozen_string_literal: true

module ErrorRadar
  module Api
    class ErrorsController < BaseController
      PER_PAGE = 50

      # GET /api/errors
      def index
        scope  = build_scope
        total  = scope.count
        page   = [params[:page].to_i, 1].max
        total_pages = [(total.to_f / PER_PAGE).ceil, 1].max
        page   = [page, total_pages].min

        errors = scope.limit(PER_PAGE).offset((page - 1) * PER_PAGE)

        render json: {
          data: errors.map { |e| serialize(e) },
          meta: { total: total, page: page, per_page: PER_PAGE, total_pages: total_pages }
        }
      end

      # GET /api/errors/:id
      def show
        log = ErrorLog.find(params[:id])
        render json: { data: serialize(log, detail: true) }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Not found' }, status: :not_found
      end

      # PATCH /api/errors/:id
      def update
        log        = ErrorLog.find(params[:id])
        new_status = params[:status].to_s

        unless ErrorLog.statuses.key?(new_status)
          return render json: { error: 'invalid status' }, status: :unprocessable_entity
        end

        if new_status == 'resolved'
          log.resolve!(by: params[:resolved_by].presence, note: params[:note].presence)
        else
          log.update!(status: new_status, resolved_at: nil)
        end

        render json: { data: serialize(log) }
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Not found' }, status: :not_found
      end

      private

      def build_scope
        scope = ErrorLog.all
        scope = scope.where(status: params[:status])     if params[:status].present?   && ErrorLog.statuses.key?(params[:status])
        scope = scope.where(severity: params[:severity]) if params[:severity].present? && ErrorLog.severities.key?(params[:severity])
        scope = scope.where(category: params[:category]) if params[:category].present? && ErrorLog.categories.key?(params[:category])

        if params[:q].present?
          q = "%#{params[:q].downcase}%"
          scope = scope.where('lower(message) LIKE :q OR lower(error_class) LIKE :q OR lower(source) LIKE :q', q: q)
        end

        from = params[:from].present? ? (Date.parse(params[:from]) rescue nil) : nil
        to   = params[:to].present?   ? (Date.parse(params[:to])   rescue nil) : nil
        scope = scope.where('last_seen_at >= ?', from) if from
        scope = scope.where('last_seen_at <= ?', to.end_of_day) if to

        sort = %w[last_seen_at first_seen_at occurrences].include?(params[:sort]) ? params[:sort] : 'last_seen_at'
        dir  = params[:order] == 'asc' ? :asc : :desc
        scope.order(sort => dir)
      end

      def serialize(log, detail: false)
        data = {
          id:            log.id,
          error_class:   log.error_class,
          source:        log.source,
          message:       log.message,
          category:      log.category,
          severity:      log.severity,
          status:        log.status,
          occurrences:   log.occurrences,
          first_seen_at: log.first_seen_at&.iso8601,
          last_seen_at:  log.last_seen_at&.iso8601,
          resolved_at:   log.resolved_at&.iso8601,
          resolved_by:   log.resolved_by
        }

        if detail
          data.merge!(
            fingerprint:     log.fingerprint,
            resolution_note: log.resolution_note,
            http_status:     log.http_status,
            request_url:     log.request_url,
            api_code:        log.api_code,
            api_subcode:     log.api_subcode,
            context:         log.context,
            backtrace:       log.backtrace
          )
        end

        if log.class.column_names.include?('github_issue_url')
          data[:github_issue_url] = log.github_issue_url
        end

        data
      end
    end
  end
end
