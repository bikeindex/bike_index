# frozen_string_literal: true

module GraphingHelper
  def group_by_method(time_range)
    if time_range.last - time_range.first < 3601
      :group_by_minute
    elsif time_range.last - time_range.first < 500_000 # around 6 days
      :group_by_hour
    elsif time_range.last - time_range.first < 5_000_000 # around 60 days
      :group_by_day
    elsif time_range.last - time_range.first < 32_000_000 # A little over a year
      :group_by_week
    else
      :group_by_month
    end
  end

  def humanized_time_range(time_range)
    return "in the past #{@period}" unless @period == "custom"
    group_by = group_by_method(time_range)
    if group_by == :group_by_minute
      precision_class = "preciseTimeSeconds"
    elsif group_by == :group_by_hour
      precision_class = "preciseTime"
    else
      precision_class = ""
    end
    content_tag(:span) do
      concat "from "
      concat content_tag(:em, l(time_range.first, format: :convert_time), class: "convertTime #{precision_class}")
      concat " to "
      concat content_tag(:em, l(time_range.last, format: :convert_time), class: "convertTime #{precision_class}")
    end
  end

  def organization_dashboard_bikes_graph_data(time_range)
    # Note: by specifying the range parameter, we force it to display empty days
    [
      {
        name: "Organization registrations",
        data: @bikes_in_organizations.send(group_by_method(time_range), "bikes.created_at", time_zone: @timezone, range: @time_range, format: group_by_format(@time_range)).count,
      },
      {
        name: "Self registrations",
        data: @bikes_not_in_organizations.send(group_by_method(time_range), "bikes.created_at", time_zone: @timezone, range: @time_range, format: group_by_format(@time_range)).count,
      },
    ]
  end
end
