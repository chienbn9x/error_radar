# frozen_string_literal: true

module ErrorRadar
  class ErrorComment < ApplicationRecord
    belongs_to :error_log

    validates :body, presence: true

    scope :chronological, -> { order(created_at: :asc) }
  end
end
