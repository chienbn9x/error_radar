# frozen_string_literal: true

module ErrorRadar
  module Integrations
    # Registers ErrorRadar::ErrorLog as a first-class RailsAdmin model (a triage
    # board) plus four member actions: start / resolve / ignore / reopen.
    # Everything is guarded so a host without RailsAdmin is unaffected.
    module RailsAdmin
      MODEL = 'ErrorRadar::ErrorLog'

      # status -> { update attrs, flash verb, icon }
      ACTIONS = {
        start_error_log:   { icon: 'fa-solid fa-person-digging', verb: 'marked in progress', update: { status: :in_progress } },
        ignore_error_log:  { icon: 'fa-solid fa-ban',            verb: 'ignored',            update: { status: :ignored } },
        reopen_error_log:  { icon: 'fa-solid fa-rotate-left',    verb: 'reopened',           method: :reopen! },
        resolve_error_log: { icon: 'fa-solid fa-circle-check',   verb: 'marked resolved',    method: :resolve! }
      }.freeze

      def self.install!
        define_actions!
        configure_model!
      rescue StandardError => e
        ErrorRadar::Tracking.warn_internal("RailsAdmin integration failed: #{e.class}: #{e.message}")
      end

      def self.define_actions!
        require 'rails_admin/config/actions'
        require 'rails_admin/config/actions/base'

        ACTIONS.each do |name, spec|
          next if ::RailsAdmin::Config::Actions.find(name)

          klass = Class.new(::RailsAdmin::Config::Actions::Base) do
            register_instance_option(:only) { MODEL }
            register_instance_option(:member) { true }
            register_instance_option(:http_methods) { %i[get put] }
            register_instance_option(:link_icon) { spec[:icon] }
            register_instance_option(:pjax?) { false }
            register_instance_option(:turbo?) { false }
            register_instance_option(:controller) do
              proc do
                actor = (_current_user.try(:email) rescue nil)
                if spec[:method] == :resolve!
                  @object.resolve!(by: actor)
                elsif spec[:method]
                  @object.public_send(spec[:method])
                else
                  @object.update!(spec[:update])
                end
                flash[:notice] = "Error ##{@object.id} #{spec[:verb]}."
                redirect_to back_or_index
              end
            end
          end

          const_name = name.to_s.split('_').map(&:capitalize).join
          ErrorRadar::Integrations::RailsAdmin.const_set(const_name, klass) unless const_defined?(const_name)
          ::RailsAdmin::Config::Actions.register(name, klass)
        end
      end

      def self.configure_model!
        ::RailsAdmin.config do |config|
          config.model MODEL do
            navigation_label 'Monitoring'
            navigation_icon 'fa-solid fa-triangle-exclamation'
            label 'Error / Task'
            label_plural 'Errors / Tasks'
            weight(-100)

            list do
              scopes %i[unresolved] + [nil] + %i[open in_progress resolved ignored]
              sort_by :last_seen_at
              items_per_page 50

              field :id
              field :status do
                pretty_value do
                  colors = { 'open' => '#dc3545', 'in_progress' => '#fd7e14', 'resolved' => '#28a745', 'ignored' => '#6c757d' }
                  v = bindings[:object].status
                  %(<span class="label" style="padding:2px 8px;border-radius:10px;color:#fff;background:#{colors[v] || '#6c757d'}">#{v}</span>).html_safe
                end
              end
              field :severity do
                pretty_value do
                  colors = { 'info' => '#17a2b8', 'warning' => '#fd7e14', 'error' => '#dc3545', 'critical' => '#7b001c' }
                  v = bindings[:object].severity
                  %(<span class="label" style="padding:2px 8px;border-radius:10px;color:#fff;background:#{colors[v] || '#6c757d'}">#{v}</span>).html_safe
                end
              end
              field :category
              field :source
              field :error_class
              field :message do
                formatted_value { bindings[:object].short_message }
              end
              field :occurrences
              field :http_status
              field :last_seen_at
              field :first_seen_at
            end

            show do
              field :id
              field :status
              field :severity
              field :category
              field :source
              field :error_class
              field :message
              field :occurrences
              field :first_seen_at
              field :last_seen_at
              field :http_status
              field :api_code
              field :api_subcode
              field :request_url
              field :context do
                pretty_value do
                  %(<pre style="white-space:pre-wrap;max-height:400px;overflow:auto">#{JSON.pretty_generate(bindings[:object].context || {})}</pre>).html_safe
                end
              end
              field :backtrace do
                pretty_value do
                  %(<pre style="white-space:pre-wrap;max-height:500px;overflow:auto">#{ERB::Util.html_escape(bindings[:object].backtrace)}</pre>).html_safe
                end
              end
              field :resolved_at
              field :resolved_by
              field :resolution_note
              field :created_at
              field :updated_at
            end

            edit do
              field :status
              field :severity
              field :resolution_note
            end
          end
        end
      end
    end
  end
end
