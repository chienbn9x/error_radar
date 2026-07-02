# frozen_string_literal: true

require 'rails/generators/active_record'

module ErrorRadar
  module Generators
    class UpgradeV060Generator < ActiveRecord::Generators::Base
      source_root File.expand_path('templates', __dir__)

      argument :name, type: :string, default: 'upgrade_v060'

      desc 'Creates the error_radar_occurrences table for per-hit occurrence history (v0.7.0).'

      def create_migration
        migration_template 'create_error_radar_occurrences.rb.tt',
                           'db/migrate/create_error_radar_occurrences.rb'
      end
    end
  end
end
