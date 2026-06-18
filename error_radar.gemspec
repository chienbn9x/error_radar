# frozen_string_literal: true

require_relative 'lib/error_radar/version'

Gem::Specification.new do |spec|
  spec.name        = 'error_radar'
  spec.version     = ErrorRadar::VERSION
  spec.authors     = ['chienbn9x']
  spec.email       = ['chienbn9x@gmail.com']

  spec.summary     = 'Drop-in error tracking & task board for Rails apps.'
  spec.description  = 'Captures unhandled exceptions from controllers, Rack, Sidekiq and ' \
                     'ActiveJob, deduplicates them by fingerprint, and exposes a kanban ' \
                     'dashboard (and optional RailsAdmin board) to triage them as tasks.'
  spec.homepage    = 'https://github.com/chienbn9x/error_radar'
  spec.license     = 'MIT'
  spec.required_ruby_version = '>= 3.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md', 'CHANGELOG.md']
  end

  # Engine works on Rails 7.0+. Enums use the classic `enum name: {...}` form
  # which is supported through Rails 7.x; see README for Rails 8 notes.
  spec.add_dependency 'rails', '>= 7.0', '< 9'

  spec.add_development_dependency 'sqlite3', '~> 1.4'
end
