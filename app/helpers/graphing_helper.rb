# frozen_string_literal: true

module GraphingHelper
  def group_by_method(timeperiod)
    if timeperiod.last - timeperiod.first < 3601
      :group_by_minute
    elsif timeperiod.last - timeperiod.first < 500_000
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
  def humanized_time_range
    "over the past #{@period}"
  end

  def organization_dashboard_bikes_graph_data
    [
      { name: "Organization registrations", data: @bikes_in_organizations.send(group_by_method(@time_range), "bikes.created_at").count },
    # { name: "Self registrations", data: @bikes_not_in_organizations.send(group_by_method(@time_range), "bikes.created_at").count },
    ]
  end
end
