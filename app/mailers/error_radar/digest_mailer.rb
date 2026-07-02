# frozen_string_literal: true

module ErrorRadar
  class DigestMailer < ActionMailer::Base
    layout false

    def digest(data, period: :daily)
      @data      = data
      @period    = period
      @app_name  = ErrorRadar.config.app_name ||
                   (defined?(Rails) && Rails.application ? Rails.application.class.module_parent_name : 'App')
      @app_host  = ErrorRadar.config.app_host.to_s.chomp('/')

      period_label = period == :weekly ? 'Weekly' : 'Daily'
      subject = "[#{@app_name}] #{period_label} Digest — " \
                "#{data[:new_this_period]} new · " \
                "#{data[:unresolved]} open · " \
                "#{data[:resolved_this_period]} resolved"

      recipients = ErrorRadar.config.digest_recipients.any? ?
                   ErrorRadar.config.digest_recipients :
                   ErrorRadar.config.email_recipients

      mail(
        to:      recipients,
        from:    ErrorRadar.config.email_from || 'noreply@localhost',
        subject: subject
      )
    end
  end
end
