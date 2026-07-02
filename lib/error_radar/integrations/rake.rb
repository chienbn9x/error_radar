# frozen_string_literal: true

module ErrorRadar
  module Integrations
    module Rake
      # Prepended into Rake::Task to auto-capture exceptions raised inside any
      # task body. Uses `prepend` (not alias_method) so it composes safely with
      # any other patches already in place — including older versions of this
      # integration that may be in the host app's lib/tasks/error_radar.rake.
      module Capture
        def execute(args = nil)
          super
        rescue Exception => e # rubocop:disable Lint/RescueException
          # Never try to capture signals or stack overflows — we can't recover.
          raise if e.is_a?(SignalException) || e.is_a?(SystemStackError) || e.is_a?(NoMemoryError)

          # Thread-local guard: if capture itself fails and re-raises, we must
          # not enter an infinite rescue loop.
          unless Thread.current[:error_radar_rake_capturing]
            Thread.current[:error_radar_rake_capturing] = true
            begin
              ErrorRadar.capture(
                e,
                source:   "rake:#{name}",
                category: :background_job,
                context:  { task: name }
              )
            ensure
              Thread.current[:error_radar_rake_capturing] = false
            end
          end
          raise
        end
      end

      def self.install!
        # `ancestors.include?` is idempotent across multiple calls AND across
        # multiple versions of the gem that may both try to install.
        return if ::Rake::Task.ancestors.include?(Capture)

        ::Rake::Task.prepend(Capture)
      end
    end
  end
end
