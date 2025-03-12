# frozen_string_literal: true

module StatusHumanizable
  extend ActiveSupport::Concern

  def self.status_humanized(str)
    return nil unless str.present?

    str.humanize.downcase
  end

  def status_humanized
    self.class.status_humanized(status)
  end
end
