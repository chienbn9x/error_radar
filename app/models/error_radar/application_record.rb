# frozen_string_literal: true

module ErrorRadar
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
