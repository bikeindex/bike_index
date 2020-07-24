module AppointmentStatusable
  extend ActiveSupport::Concern

  included do
    scope :in_line, -> { where(status: AppointmentUpdate.in_line_statuses).line_ordered }
    scope :paging_or_on_deck, -> { where(status: %w[on_deck paging]).line_ordered }
    scope :line_not_paging_or_on_deck, -> { where.not(status: %w[on_deck paging]).in_line }
    scope :unresolved, -> { where(status: AppointmentUpdate.unresolved_statuses) }
    scope :resolved, -> { where(status: AppointmentUpdate.resolved_statuses).line_ordered }

    enum status: AppointmentUpdate::STATUS_ENUM
  end

  module ClassMethods
    def statuses
      AppointmentUpdate.statuses
    end

    def in_line_statuses
      AppointmentUpdate.in_line_statuses
    end

    def resolved_statuses
      AppointmentUpdate.resolved_statuses
    end

    def unresolved_statuses
      AppointmentUpdate.unresolved_statuses
    end
  end

  def in_line?; AppointmentUpdate.in_line_statuses.include?(status) end

  def no_longer_in_line?; !in_line? end

  def resolved?; AppointmentUpdate.resolved_statuses.include?(status) end

  def unresolved?; AppointmentUpdate.unresolved_statuses.include?(status) end

  def paging_or_on_deck?; on_deck? || paging? end
end
