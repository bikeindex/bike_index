# frozen_string_literal: true

module GraphingHelper
  def group_by_method(timeperiod)
    if timeperiod.last - timeperiod.first < 3601
      :group_by_minute
    elsif timeperiod.last - timeperiod.first < 500_000 # around 6 days
      :group_by_hour
    elsif timeperiod.last - timeperiod.first < 5_000_000 # around 60 days
      :group_by_day
    elsif timeperiod.last - timeperiod.first < 32_000_000 # A little over a year
      :group_by_week
    else
      :group_by_month
    end
  end

  # Currently just deals with the past, not custom date ranges
  # also, we're passing timeperiod but using period to actually render, timeperiod is what will actually be used, and tested, stubbing for now
  def humanized_time_range(timeperiod)
    "over the past #{@period}"
  end

  def group_by_format(timeperiod)
    if timeperiod.last - timeperiod.first < 86401 # 24 hours
      "%l:%M %p"
    else
      nil # Let it fallback to the default handling
    end
  end

  def organization_dashboard_bikes_graph_data(timeperiod)
    # Note: by specifying the range parameter, we force it to display empty days
    [
      {
        name: "Organization registrations",
        data: @bikes_in_organizations.send(group_by_method(timeperiod), "bikes.created_at", time_zone: @timezone, range: @time_range, format: group_by_format(@time_range)).count,
      },
      {
        name: "Self registrations",
        data: @bikes_not_in_organizations.send(group_by_method(timeperiod), "bikes.created_at", time_zone: @timezone, range: @time_range, format: group_by_format(@time_range)).count,
      },
    ]
  end
end
