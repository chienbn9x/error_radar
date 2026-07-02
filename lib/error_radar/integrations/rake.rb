# frozen_string_literal: true

module ErrorRadar
  module Integrations
    # Patches Rake::Task#execute so any exception raised inside a rake task is
    # automatically captured as an ErrorLog, then re-raised so rake's normal
    # failure handling (exit code, output) is unaffected.
    module Rake
      def self.install!
        return if @installed

        @installed = true

        ::Rake::Task.class_eval do
          alias_method :error_radar_original_execute, :execute

          def execute(args = nil)
            error_radar_original_execute(args)
          rescue Exception => e # rubocop:disable Lint/RescueException
            ErrorRadar.capture(
              e,
              source: "rake:#{name}",
              category: :background_job,
              context: { task: name }
            )
            raise
          end
        end
      end
    end
  end
end
