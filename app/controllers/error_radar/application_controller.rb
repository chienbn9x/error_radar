# frozen_string_literal: true

module ErrorRadar
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout 'error_radar/application'

    private

    # Delegates to the host-configured auth proc. nil => open access.
    def authenticate_request!
      auth = ErrorRadar.config.authenticate
      return if auth.nil?

      auth.call(self)
    end

    def error_radar_current_user
      cu = ErrorRadar.config.current_user
      cu.respond_to?(:call) ? cu.call(self) : nil
    end
  end
end
