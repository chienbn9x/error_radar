# frozen_string_literal: true

module ErrorRadar
  class ErrorMailer < ActionMailer::Base
    layout false

    def new_error(error_log, event = :recurring)
      @error      = error_log
      @event      = event
      @spike_data = error_log.instance_variable_get(:@spike_data)
      @url        = build_url
      @app_name   = ErrorRadar::Notifier.app_name

      subject = case event
                when :spike
                  "[#{@app_name}] SPIKE #{@error.error_class}: #{@spike_data[:count]} hits in #{@spike_data[:window_minutes]} min"
                when :new_error
                  "[#{@app_name}] New #{@error.severity}: #{@error.error_class}"
                else
                  "[#{@app_name}] #{@error.severity.capitalize}: #{@error.error_class}"
                end

      mail(
        to:      ErrorRadar.config.email_recipients,
        from:    ErrorRadar.config.email_from || 'noreply@localhost',
        subject: subject
      )
    end

    private

    def build_url
      host = ErrorRadar.config.app_host.to_s.chomp('/')
      return nil if host.empty?

      "#{host}/error_radar/errors/#{@error.id}"
    end
  end
end
