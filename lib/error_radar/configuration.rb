# frozen_string_literal: true

module ErrorRadar
  # Holds every host-app-specific decision so the engine stays decoupled.
  # Configure from an initializer (see the install generator's template).
  class Configuration
    # Built-in categories (name => stored integer). Hosts can override the whole
    # map (`config.categories = {...}`) or add their own (`register_category`).
    DEFAULT_CATEGORIES = {
      application:    0, # generic Ruby/Rails runtime error
      external_api:   1, # any 3rd-party API error
      background_job: 2, # uncategorised background-job failure
      syntax:         3, # SyntaxError / NameError / NoMethodError / ArgumentError / TypeError
      database:       4, # ActiveRecord / DB level
      network:        5  # timeouts, connection resets, DNS, ...
    }.freeze

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

    # The category name => integer map backing ErrorLog's `category` enum.
    # Read-only accessor; mutate through `categories=` or `register_category`
    # so the built-in defaults are always preserved.
    attr_reader :categories

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
      @categories         = DEFAULT_CATEGORIES.dup
    end

    # Replace the category map. The built-in defaults are merged in first, so a
    # host only needs to list what it adds or renumbers:
    #   config.categories = { instagram_api: 6, background_job: 7 }
    # Stored integers must stay stable once data exists — treat them as a schema.
    def categories=(hash)
      merged = DEFAULT_CATEGORIES.merge(hash.transform_keys(&:to_sym))
      assert_unique_values!(merged)
      @categories = merged
    end

    # Add a single custom category without disturbing the rest:
    #   config.register_category(:instagram_api, 6)
    def register_category(name, value)
      name = name.to_sym
      value = Integer(value)
      if @categories[name] && @categories[name] != value
        raise ArgumentError, "category #{name.inspect} already mapped to #{@categories[name]}"
      end
      existing = @categories.key(value)
      if existing && existing != name
        raise ArgumentError, "category value #{value} already used by #{existing.inspect}"
      end
      @categories = @categories.merge(name => value)
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

    private

    def assert_unique_values!(map)
      dupes = map.values.tally.select { |_, n| n > 1 }.keys
      return if dupes.empty?

      raise ArgumentError, "category values must be unique; collisions on #{dupes.inspect}"
    end
  end
end
