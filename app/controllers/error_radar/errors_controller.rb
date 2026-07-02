# frozen_string_literal: true

module ErrorRadar
  class ErrorsController < ApplicationController
    before_action :authenticate_request!
    before_action :set_error, only: %i[show update_status destroy create_github_issue]

    rescue_from ActiveRecord::RecordNotFound do
      redirect_to errors_path, alert: 'Error not found.'
    end

    PER_PAGE = 50

    def index
      scope = build_scope
      @total_count  = scope.count
      @page         = [params[:page].to_i, 1].max
      @total_pages  = [(@total_count.to_f / PER_PAGE).ceil, 1].max
      @page         = [@page, @total_pages].min if @total_pages > 0
      @errors       = scope.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
      @filter_params = active_filter_params
      @pages        = pagination_pages(@page, @total_pages)
    end

    def show
      @occurrences = []
      return unless ErrorRadar.config.track_occurrences

      begin
        @occ_page       = [params[:occ_page].to_i, 1].max
        occ_per_page    = 20
        @occ_total      = @error.occurrences.count
        @occ_total_pages = [(@occ_total.to_f / occ_per_page).ceil, 1].max
        @occ_page       = [@occ_page, @occ_total_pages].min
        @occurrences    = @error.occurrences.recent
                                .limit(occ_per_page)
                                .offset((@occ_page - 1) * occ_per_page)
      rescue ActiveRecord::StatementInvalid
        @occurrences = []
      end
    end

    def update_status
      new_status = params[:status].to_s
      unless ErrorLog.statuses.key?(new_status)
        return render json: { ok: false, error: 'invalid status' }, status: :unprocessable_entity
      end

      if new_status == 'resolved'
        @error.resolve!(by: error_radar_current_user, note: params[:note].presence)
      else
        @error.update!(status: new_status, resolved_at: nil)
      end

      render json: { ok: true, id: @error.id, status: @error.status }
    end

    def destroy
      @error.destroy!
      render json: { ok: true }
    end

    def create_github_issue
      unless github_configured?
        return render json: { ok: false, error: 'GitHub not configured (set config.github_token and config.github_repo)' },
                      status: :unprocessable_entity
      end

      if ErrorLog.column_names.include?('github_issue_url') && @error.github_issue_url.present?
        return render json: { ok: false, error: 'Issue already created', url: @error.github_issue_url },
                      status: :unprocessable_entity
      end

      require 'error_radar/integrations/github'
      result = ErrorRadar::Integrations::Github.create_issue(
        @error,
        token: ErrorRadar.config.github_token,
        repo:  ErrorRadar.config.github_repo
      )

      if result['html_url']
        @error.update!(github_issue_url: result['html_url']) if ErrorLog.column_names.include?('github_issue_url')
        render json: { ok: true, url: result['html_url'], number: result['number'] }
      else
        render json: { ok: false, error: result['message'] || 'GitHub API error' },
               status: :unprocessable_entity
      end
    rescue StandardError => e
      render json: { ok: false, error: e.message }, status: :internal_server_error
    end

    def bulk
      ids = Array(params[:ids]).map(&:to_i).select(&:positive?)
      action = params[:bulk_action].to_s

      if ids.empty?
        return render json: { ok: false, error: 'no ids selected' }, status: :unprocessable_entity
      end
      unless %w[resolve ignore reopen delete].include?(action)
        return render json: { ok: false, error: 'unknown action' }, status: :unprocessable_entity
      end

      count = apply_bulk(ids, action)
      render json: { ok: true, count: count, action: action }
    end

    private

    def set_error
      @error = ErrorLog.find(params[:id])
    end

    def build_scope
      scope = ErrorLog.all

      if params[:status].present? && ErrorLog.statuses.key?(params[:status])
        scope = scope.where(status: params[:status])
      end

      if params[:severity].present? && ErrorLog.severities.key?(params[:severity])
        scope = scope.where(severity: params[:severity])
      end

      if params[:category].present? && ErrorLog.categories.key?(params[:category])
        scope = scope.where(category: params[:category])
      end

      if params[:q].present?
        q = "%#{params[:q].downcase}%"
        scope = scope.where(
          'lower(message) LIKE :q OR lower(error_class) LIKE :q OR lower(source) LIKE :q', q: q
        )
      end

      from_date = params[:from].present? ? (Date.parse(params[:from]) rescue nil) : nil
      to_date   = params[:to].present?   ? (Date.parse(params[:to]) rescue nil)   : nil
      scope = scope.where('last_seen_at >= ?', from_date) if from_date
      scope = scope.where('last_seen_at <= ?', to_date.end_of_day) if to_date

      sort_col = %w[last_seen_at first_seen_at occurrences].include?(params[:sort]) ? params[:sort] : 'last_seen_at'
      sort_dir = params[:order] == 'asc' ? :asc : :desc
      scope.order(sort_col => sort_dir)
    end

    def apply_bulk(ids, action)
      case action
      when 'resolve'
        ErrorLog.where(id: ids).update_all(
          status: ErrorLog.statuses[:resolved],
          resolved_at: Time.current,
          resolved_by: error_radar_current_user
        )
      when 'ignore'
        ErrorLog.where(id: ids).update_all(status: ErrorLog.statuses[:ignored])
      when 'reopen'
        ErrorLog.where(id: ids).update_all(status: ErrorLog.statuses[:open], resolved_at: nil)
      when 'delete'
        ErrorLog.where(id: ids).delete_all
      end
      ids.size
    end

    def github_configured?
      ErrorRadar.config.github_token.present? && ErrorRadar.config.github_repo.present?
    end

    def active_filter_params
      params.permit(:q, :status, :severity, :category, :from, :to, :sort, :order).to_h
    end

    def pagination_pages(current, total)
      return [] if total <= 1
      return (1..total).to_a if total <= 9

      visible = [1, total, *(current - 2..current + 2)]
                .select { |p| p.between?(1, total) }
                .sort.uniq
      result = []
      visible.each_with_index do |p, i|
        result << '...' if i > 0 && p > visible[i - 1] + 1
        result << p
      end
      result
    end
  end
end
