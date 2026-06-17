# frozen_string_literal: true

module ErrorRadar
  # The capture facade. Auto-classifies common exception types, lets the host
  # app plug in custom rules, then persists/rolls-up an ErrorLog. Never raises.
  module Tracking
    module_function

    def capture(exception, source: nil, category: nil, severity: nil, context: {})
      return nil unless ErrorRadar.config.enabled

      category ||= categorize(exception)
      severity ||= default_severity(exception, category)

      attrs = {
        category: category,
        severity: severity,
        error_class: exception.class.name,
        source: source || infer_source(exception),
        message: exception.message,
        backtrace: Array(exception.backtrace).first(ErrorRadar.config.backtrace_lines),
        context: context
      }

      ErrorRadar.config.detail_extractors.each do |extractor|
        extra = safe_call(extractor, exception)
        attrs.merge!(extra.compact) if extra.is_a?(Hash)
      end

      ErrorRadar::ErrorLog.record(**attrs)
    rescue StandardError => e
      warn_internal("capture failed: #{e.class}: #{e.message}")
      nil
    end

    # Wrap a block (rake task, cron script, manual maintenance) so any exception
    # is captured and then re-raised. Use at boundaries the web/Sidekiq handlers
    # don't cover.
    def monitor(source, category: nil, severity: nil, context: {})
      yield
    rescue StandardError => e
      capture(e, source: source, category: category, severity: severity, context: context)
      raise
    end

    # Log a problem without an exception object.
    def notify(message, category: :application, severity: :error, source: nil, context: {})
      return nil unless ErrorRadar.config.enabled

      ErrorRadar::ErrorLog.record(category: category, severity: severity, message: message, source: source, context: context)
    rescue StandardError => e
      warn_internal("notify failed: #{e.class}: #{e.message}")
      nil
    end

    def categorize(exception)
      ErrorRadar.config.categorizers.each do |rule|
        cat = safe_call(rule, exception)
        return cat if cat
      end

      if defined?(ActiveRecord::ActiveRecordError) && exception.is_a?(ActiveRecord::ActiveRecordError)
        :database
      elsif exception.is_a?(SyntaxError) || exception.is_a?(NameError) ||
            exception.is_a?(ArgumentError) || exception.is_a?(TypeError)
        :syntax
      elsif network_error?(exception)
        :network
      else
        :application
      end
    end

    def network_error?(exception)
      names = %w[
        Net::OpenTimeout Net::ReadTimeout Errno::ECONNREFUSED Errno::ECONNRESET
        Errno::EHOSTUNREACH Errno::ETIMEDOUT SocketError Timeout::Error
        OpenSSL::SSL::SSLError EOFError Faraday::ConnectionFailed Faraday::TimeoutError
      ]
      klass = exception.class
      while klass
        return true if names.include?(klass.name)

        klass = klass.superclass
      end
      false
    end

    def default_severity(_exception, category)
      case category.to_sym
      when :syntax, :database then :critical
      when :network, :external_api then :warning
      else :error
      end
    end

    def infer_source(exception)
      line = Array(exception.backtrace).find { |l| l.include?('/app/') } || Array(exception.backtrace).first
      return 'unknown' if line.nil? || line.empty?

      line.split(':').first.to_s.split('/app/').last || line
    end

    def safe_call(callable, *args)
      callable.call(*args)
    rescue StandardError => e
      warn_internal("custom rule failed: #{e.class}: #{e.message}")
      nil
    end

    def warn_internal(message)
      logger = defined?(Rails) && Rails.respond_to?(:logger) ? Rails.logger : nil
      logger ? logger.error("[ErrorRadar] #{message}") : warn("[ErrorRadar] #{message}")
    end
  end
end
