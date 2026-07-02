# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module ErrorRadar
  module Generators
    class UpgradeV050Generator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      desc 'Generates the migration for Error Radar v0.5.0 (adds github_issue_url column).'

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_file
        migration_template(
          'add_github_issue_to_error_radar_error_logs.rb.tt',
          'db/migrate/add_github_issue_to_error_radar_error_logs.rb'
        )
      end
    end
  end
end
