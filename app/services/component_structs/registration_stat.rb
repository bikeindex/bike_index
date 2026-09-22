# frozen_string_literal: true

module ComponentStructs
  # One row of the org registrations chart card. previous_count is nil where there's
  # no earlier window to compare against, and the row renders without a delta.
  RegistrationStat = Data.define(:key, :count, :previous_count) do
    def initialize(key:, count:, previous_count: nil)
      super
    end

    def delta = previous_count && count - previous_count

    # Percent against an empty earlier window is unbounded, so those rows show the count moved
    def delta_display
      return nil if delta.nil? || (count.zero? && previous_count.zero?)
      return format("%+d", delta) if previous_count.zero?

      format("%+d%%", (delta * 100.0 / previous_count).round)
    end

    # More thefts is the one metric where the number going up is bad news
    def positive? = (key == :stolen) ? delta.to_i <= 0 : delta.to_i >= 0
  end
end
