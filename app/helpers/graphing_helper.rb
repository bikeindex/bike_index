# frozen_string_literal: true

module GraphingHelper
  def time_range_counts(collection:, column: "created_at", time_range: nil)
    time_range ||= @time_range
    # Note: by specifying the range parameter, we force it to display empty days
    collection.send(group_by_method(time_range), column, range: time_range, format: group_by_format(time_range))
              .count
  end

  def time_range_amounts(collection:, column: "created_at", amount_column: "amount_cents", time_range: nil)
    time_range ||= @time_range
    # Note: by specifying the range parameter, we force it to display empty days
    collection.send(group_by_method(time_range), column, range: time_range, format: group_by_format(time_range))
              .sum(amount_column)
              .map { |k, v| [k, (v.to_f / 100.00).round(2)] } # Convert cents to dollars
              .to_h
  end

  def group_by_method(time_range)
    if time_range.last - time_range.first < 3601 # 1.hour + 1 second
      :group_by_minute
    elsif time_range.last - time_range.first < 500_000 # around 6 days
      :group_by_hour
    elsif time_range.last - time_range.first < 5_000_000 # around 60 days
      :group_by_day
    elsif time_range.last - time_range.first < 31730400 # 1.year + 2.days
      :group_by_week
    else
      :group_by_month
    end
  end

  def group_by_format(time_range, group_period = nil)
    group_period ||= group_by_method(time_range)
    if group_period == :group_by_minute
      "%l:%M %p"
    elsif group_period == :group_by_hour
      "%a%l %p"
    elsif %i[group_by_day group_by_week].include?(group_period) || time_range.present? && time_range.last - time_range.first < 2.weeks.to_i
      "%a %-m-%-d"
    elsif group_period == :group_by_month
      "%Y-%-m"
    else
      nil # Let it fallback to the default handling
    end
  end

  def humanized_time_range_column(time_range_column, return_value_for_all: false)
    return nil if @period == "all" unless return_value_for_all
    humanized_text = time_range_column.to_s.gsub("_at", "").humanize.downcase
    return humanized_text.gsub("start", "started") if time_range_column.match?("start_at")
    return humanized_text.gsub("end", "ended") if time_range_column.match?("end_at")
    humanized_text
  end

  def humanized_time_range(time_range)
    return nil if @period == "all"
    return "in the past #{@period}" unless @period == "custom"
    group_period = group_by_method(time_range)
    if group_period == :group_by_minute
      precision_class = "preciseTimeSeconds"
    elsif group_period == :group_by_hour
      precision_class = "preciseTime"
    else
      precision_class = ""
    end
    content_tag(:span) do
      concat "from "
      concat content_tag(:em, l(time_range.first, format: :convert_time), class: "convertTime #{precision_class}")
      concat " to "
      if time_range.last > Time.current - 5.minutes
        concat content_tag(:em, "now")
      else
        concat content_tag(:em, l(time_range.last, format: :convert_time), class: "convertTime #{precision_class}")
      end
    end
  end

  def organization_dashboard_bikes_graph_data
    org_registrations = {
      name: "Organization registrations",
      data: time_range_counts(collection: @bikes_in_organizations, column: "bikes.created_at"),
    }
    return [org_registrations] unless current_organization.regional?
    [
      org_registrations,
      {
        name: "Self registrations",
        data: time_range_counts(collection: @bikes_not_in_organizations, column: "bikes.created_at"),
      },
    ]
  end
end
