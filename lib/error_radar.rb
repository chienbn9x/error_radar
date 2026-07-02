# frozen_string_literal: true

require 'error_radar/version'
require 'error_radar/configuration'
require 'error_radar/tracking'
require 'error_radar/notifier'
require 'error_radar/middleware'
require 'error_radar/server_monitor'
require 'error_radar/engine'

# Public entry point for the gem.
#
#   ErrorRadar.configure do |c|
#     c.authenticate  = ->(controller) { controller.send(:authenticate_admin!) }
#     c.current_user  = ->(controller) { controller.current_admin&.email }
#   end
#
#   ErrorRadar.capture(exception, source: 'SomeJob', context: { post_id: 1 })
#   ErrorRadar.notify('Custom problem', category: :external_api, severity: :warning)
#   ErrorRadar.monitor('NightlyRakeTask') { do_work }
module ErrorRadar
  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    # Reset configuration — mostly useful in tests.
    def reset_config!
      @config = Configuration.new
    end

    def capture(exception, **kwargs)
      Tracking.capture(exception, **kwargs)
    end

    def notify(message, **kwargs)
      Tracking.notify(message, **kwargs)
    end

    def monitor(source, **kwargs, &block)
      Tracking.monitor(source, **kwargs, &block)
    end
  end
end
