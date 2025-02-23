# frozen_string_literal: true

module ActivePeriodable
  extend ActiveSupport::Concern

  included do
    scope :period_started, -> { where("start_at < ?", Time.current) }
    scope :period_active, -> {
      period_started.where(end_at: nil).or(period_started.where("end_at > ?", Time.current))
    }
    scope :period_not_started, -> { where(start_at: nil).or(where("start_at > ?", Time.current)) }
    scope :period_inactive, -> { period_not_started.or(where("end_at < ?", Time.current)) }
    scope :time_ordered, -> { reorder(:start_at) }
  end

  def period_active?
    return false unless start_at.present? && start_at <= Time.current

    end_at.blank? || end_at > Time.current
  end

  def period_inactive?
    !period_active?
  end
end
