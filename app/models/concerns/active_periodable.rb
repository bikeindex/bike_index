# frozen_string_literal: true

module ActivePeriodable
  extend ActiveSupport::Concern

  included do
    scope :active, -> { where(active: true) }
    scope :inactive, -> { where(active: false) }

    before_save :set_active
  end

  def inactive?
    !active?
  end

  def set_active
    self.active = calculated_active?
  end

  private

  def calculated_active?
    return false if start_at.blank? || start_at > Time.current

    end_at.blank? || end_at > Time.current
  end
end
