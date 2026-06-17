# frozen_string_literal: true

module ErrorRadar
  # Rack middleware that captures every unhandled web-layer exception as an
  # ErrorLog, then re-raises so Rails' normal exception rendering still happens.
  # Inserted just below ActionDispatch::DebugExceptions.
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue Exception => e # rubocop:disable Lint/RescueException
      capture(e, env) unless ignored?(e)
      raise
    end

    private

    def ignored?(exception)
      ErrorRadar.config.ignored_exceptions.include?(exception.class.name)
    end

    def capture(exception, env)
      request = ActionDispatch::Request.new(env)
      ErrorRadar.capture(
        exception,
        source: "#{request.request_method} #{request.path}",
        context: {
          controller: env['action_dispatch.request.path_parameters']&.dig(:controller),
          action: env['action_dispatch.request.path_parameters']&.dig(:action),
          path: request.fullpath,
          method: request.request_method,
          ip: request.remote_ip,
          params: filtered_params(request)
        }.compact
      )
    rescue StandardError => e
      ErrorRadar::Tracking.warn_internal("middleware capture failed: #{e.class}: #{e.message}")
    end

    def filtered_params(request)
      request.filtered_parameters.except('controller', 'action').deep_transform_values do |v|
        v.is_a?(String) && v.length > 500 ? "#{v[0, 500]}…" : v
      end.tap do |p|
        ErrorRadar.config.sensitive_params.each { |k| p[k] = '[FILTERED]' if p.key?(k) }
      end
    rescue StandardError
      {}
    end
  end
end
