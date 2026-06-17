# frozen_string_literal: true

module ErrorRadar
  # Holds every host-app-specific decision so the engine stays decoupled.
  # Configure from an initializer (see the install generator's template).
  class Configuration
    # Master switch — set false (e.g. in test env) to make capture a no-op.
    attr_accessor :enabled

    # How many backtrace lines to persist.
    attr_accessor :backtrace_lines

    # Truncate stored messages to this many chars.
    attr_accessor :max_message_length

    # Exception class names the Rack middleware must NOT log (expected client
    # outcomes: routing errors, 404s, bad requests, ...).
    attr_accessor :ignored_exceptions

    # Request param keys to scrub before persisting them in `context`.
    attr_accessor :sensitive_params

    # Integration toggles.
    attr_accessor :install_middleware, :install_sidekiq, :install_rails_admin

    # Custom classification rules. Each is a callable `->(exception) { :category | nil }`.
    # The first rule that returns a non-nil category wins; built-in rules run after.
    attr_accessor :categorizers

    # Extract extra structured columns from custom exception types. Each is a
    # callable `->(exception) { { http_status:, request_url:, api_code:, api_subcode: } | nil }`.
    attr_accessor :detail_extractors

    # Optional Sidekiq process expectations for the dashboard's server panel.
    # Each entry: { key:, name:, tag:, host:, queue_hint: }. Empty => the panel
    # simply lists whatever live processes exist.
    attr_accessor :expected_servers

    # Dashboard auth: `->(controller) { ... }` run as a before_action. Raise /
    # redirect inside it to deny access. nil => no auth (NOT recommended in prod).
    attr_accessor :authenticate

    # `->(controller) { "who@acted" }` — stamped onto resolved errors.
    attr_accessor :current_user

    def initialize
      @enabled            = true
      @backtrace_lines    = 30
      @max_message_length = 4_000
      @ignored_exceptions = %w[
        ActionController::RoutingError
        ActiveRecord::RecordNotFound
        ActionController::ParameterMissing
        ActionController::UnknownFormat
        ActionController::BadRequest
        ActionController::InvalidAuthenticityToken
        ActionDispatch::Http::Parameters::ParseError
      ]
      @sensitive_params   = %w[password password_confirmation token access_token authorization secret]
      @install_middleware = true
      @install_sidekiq    = true
      @install_rails_admin = true
      @categorizers       = []
      @detail_extractors  = []
      @expected_servers   = []
      @authenticate       = nil
      @current_user       = nil
    end

    # Convenience DSL inside `configure`:
    #   c.categorize { |e| :external_api if e.is_a?(MyApi::Error) }
    def categorize(&block)
      @categorizers << block
    end

    #   c.extract_details { |e| { http_status: e.status } if e.is_a?(MyApi::Error) }
    def extract_details(&block)
      @detail_extractors << block
    end
  end
end
