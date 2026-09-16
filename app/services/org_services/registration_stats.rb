# frozen_string_literal: true

module OrgServices
  # The counts behind the org registrations chart card: each metric over the window,
  # and over the window of the same length before it, which the card renders as a delta.
  module RegistrationStats
    extend Functionable

    # compare: false for `all`, whose window starts at the epoch - there's no earlier one
    def for_range(bikes, time_range, compare: true)
      earlier = compare ? counts(bikes, previous_range(time_range)) : {}

      counts(bikes, time_range).map do |key, count|
        ComponentStructs::RegistrationStat.new(key:, count:, previous_count: earlier[key])
      end
    end

    def counts(bikes, time_range)
      scoped = bikes.where(created_at: time_range)

      {registrations: scoped.count,
       motorized: scoped.motorized.count,
       stolen: scoped.where(status: "status_stolen").count}
    end

    def previous_range(time_range)
      (time_range.first - UI::Chart::Component.time_range_length(time_range))..time_range.first
    end

    conceal :counts, :previous_range
  end
end
