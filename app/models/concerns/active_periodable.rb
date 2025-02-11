# frozen_string_literal: true

module ActivePeriodable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(active: true) }
    scope :inactive, -> { where(active: false) }
  end

  def inactive?
    active?
  end

  def calculated_active
    return false if start_at.blank? || start_at > Time.current

    end_at.blank? || end_at > Time.current
  end
end
