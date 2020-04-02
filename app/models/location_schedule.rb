class LocationSchedule < ApplicationRecord
  DAYS_OF_WEEK_ENUM = { monday: 0, tuesday: 1, wednesday: 2, thursday: 3, friday: 4, saturday: 5, sunday: 6 }.freeze

  enum day: DAYS_OF_WEEK_ENUM

  scope :reference, -> { where(date: nil).order(:day_int) }
  scope :specific, -> { where.not(date: nil) }

  before_validation :set_calculated_attributes

  delegate :timezone, to: :location, allow_nil: true

  def self.days_of_week; DAYS_OF_WEEK_ENUM.keys.map(&:to_s) end

  def self.weekday?(str); days_of_week.include?(str.to_s.downcase.strip) end

  def self.to_weekday(str)
    return str.downcase.strip if weekday?(str)
    if str.is_a?(Date) || str.is_a?(Time)
      wday = str.to_date.wday
      wday == 0 ? "sunday" : days_of_week[wday - 1]
    end
  end

  def self.closed_on?(day_or_date)
    raise "Not scoped to a specific location!" unless reference.count == 7
    if weekday?(day_or_date)
      day = day_or_date.downcase.strip
      reference.where(day: day).first&.closed?
    else
      if day_or_date.is_a?(Date)
        date = day_or_date
      else
        date = TimeParser.parse(day_or_date, timezone).to_date
      end
      (specific.where(date: date).first || reference.where(day: to_weekday(date)).first).closed?
    end
  end

  def closed?; hours.none? end

  def open?; !closed? end

  def open_hours
    return [] if set_closed? # Because we don't wipe hours necessarily
    schedule.dig("open_hours") || []
  end

  def appointment_hours
    return [] if set_closed? # Because we don't wipe hours necessarily
    schedule.dig("appointment_hours") || []
  end

  def set_calculated_attributes
    self.schedule ||= {}
    self.day = date.wday if date.present?
    # day_int is just the integer version of the day. I was struggling with ordering.
    # I'm sure there is a better way, but whatever
    self.day_int = DAYS_OF_WEEK_ENUM[day&.to_sym]
  end
end
