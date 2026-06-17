# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/migration'

module ErrorRadar
  module Generators
    # Run `bin/rails generate error_radar:install` to drop an initializer and the
    # error_radar_error_logs migration into the host app.
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      def self.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      def copy_initializer
        template 'initializer.rb', 'config/initializers/error_radar.rb'
      end

      def copy_migration
        migration_template 'create_error_radar_error_logs.rb.tt',
                           'db/migrate/create_error_radar_error_logs.rb'
      end

      def show_readme
        say "\nError Radar installed.", :green
        say '  1. Review config/initializers/error_radar.rb'
        say '  2. Mount the dashboard in config/routes.rb, e.g.:'
        say "       mount ErrorRadar::Engine, at: '/monitoring'", :yellow
        say '  3. Run: bin/rails db:migrate'
      end
    end
  end
end
