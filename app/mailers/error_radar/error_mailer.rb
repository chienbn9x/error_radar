# frozen_string_literal: true

module ErrorRadar
  class ErrorMailer < ActionMailer::Base
    layout false

    def new_error(error_log)
      @error    = error_log
      @is_new   = error_log.new_fingerprint?
      @url      = build_url
      @app_name = ErrorRadar::Notifier.app_name

      prefix  = @is_new ? 'New' : 'Critical'
      subject = "[#{@app_name}] #{prefix} #{@error.severity}: #{@error.error_class}"

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
