# frozen_string_literal: true

require 'rails/engine'

module ErrorRadar
  class Engine < ::Rails::Engine
    isolate_namespace ErrorRadar

    # Capture all unhandled web-layer exceptions. Run after the host's
    # config/initializers so ErrorRadar.configure has already executed.
    initializer 'error_radar.middleware', after: :load_config_initializers do |app|
      if ErrorRadar.config.install_middleware
        app.middleware.insert_after ActionDispatch::DebugExceptions, ErrorRadar::Middleware
      end
    end

    # Capture every Sidekiq job failure (incl. retries) as an ErrorLog task.
    initializer 'error_radar.sidekiq', after: :load_config_initializers do
      if ErrorRadar.config.install_sidekiq && defined?(::Sidekiq)
        require 'error_radar/integrations/sidekiq'
        ErrorRadar::Integrations::Sidekiq.install!
      end
    end

    # Register the ErrorLog board + custom actions in RailsAdmin, if present.
    config.after_initialize do
      if ErrorRadar.config.install_rails_admin && defined?(::RailsAdmin)
        require 'error_radar/integrations/rails_admin'
        ErrorRadar::Integrations::RailsAdmin.install!
      end
    end
  end
end
