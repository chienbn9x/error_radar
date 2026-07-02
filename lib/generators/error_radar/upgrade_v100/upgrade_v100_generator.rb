# frozen_string_literal: true

require 'rails/generators/active_record'

module ErrorRadar
  module Generators
    class UpgradeV100Generator < ActiveRecord::Generators::Base
      source_root File.expand_path('templates', __dir__)

      argument :name, type: :string, default: 'upgrade_v100'

      desc 'Creates tables for assignment, comments and activity log (v1.0.0).'

      def create_migration
        migration_template 'upgrade_to_v100.rb.tt',
                           'db/migrate/upgrade_error_radar_to_v100.rb'
      end
    end
  end
end
