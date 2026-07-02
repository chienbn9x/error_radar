# frozen_string_literal: true

module ErrorRadar
  class ErrorActivity < ApplicationRecord
    belongs_to :error_log

    scope :recent, -> { order(created_at: :desc) }

    ACTION_ICONS = {
      'resolved'       => '✓',
      'reopened'       => '↩',
      'in_progress'    => '▶',
      'open'           => '○',
      'ignored'        => '–',
      'assigned'       => '→',
      'unassigned'     => '×',
      'commented'      => '💬',
      'comment_deleted'=> '🗑'
    }.freeze

    def icon
      ACTION_ICONS.find { |k, _| action.to_s.start_with?(k) }&.last || '·'
    end
  end
end
