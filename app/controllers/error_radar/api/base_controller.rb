# frozen_string_literal: true

module ErrorRadar
  module Api
    class BaseController < ActionController::Base
      skip_before_action :verify_authenticity_token
      before_action :authenticate_api!

      private

      def authenticate_api!
        token = ErrorRadar.config.api_token
        return if token.nil?

        provided = request.headers['Authorization'].to_s.delete_prefix('Bearer ').strip
        render json: { error: 'Unauthorized' }, status: :unauthorized unless provided == token
      end
    end
  end
end
