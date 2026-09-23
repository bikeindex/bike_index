# frozen_string_literal: true

module GraphingHelper
  def time_range_counts(collection:, column: "created_at", time_range: nil)
    collection_grouped(collection: collection, column: column, time_range: time_range).count
  end

  def time_range_amounts(collection:, column: "created_at", amount_column: "amount_cents", time_range: nil, convert_to_dollars: false)
    result = collection_grouped(collection: collection,
      column: column, time_range: time_range).sum(amount_column)

    return result unless convert_to_dollars

    result.map { |k, v| [k, (v.to_f / 100.00).round(2)] } # Convert cents to dollars
      .to_h
  end

  # What time_range_counts returns for a collection with no matching rows, without a
  # relation to run a query through. series: because groupdate only fills the whole range
  # for a relation - an enumerable gets the buckets it found, which for [] is none
  def empty_time_range_counts(time_range = @time_range)
    [].send(group_by_method(time_range), **grouping(time_range), series: true) { it }
      .transform_values { 0 }
  end

  def time_range_length(time_range)
    time_range.last - time_range.first
  end

  def group_by_method(time_range)
    case time_range_length(time_range)
    when ...(1.hour + 1) then :group_by_minute
    when ...5.days then :group_by_hour
    when ...5_000_000 then :group_by_day # around 60 days
    when ...52.weeks then :group_by_week
    else :group_by_month
    end
  end

  def group_by_format(time_range, group_period = nil)
    group_period ||= group_by_method(time_range)
    if group_period == :group_by_minute
      "%l:%M %p"
    elsif group_period == :group_by_hour
      "%a%l %p"
    elsif group_period == :group_by_month
      "%Y-%-m"
    elsif group_period == :group_by_day && (time_range_length(time_range) < 10.days)
      "%a %-m-%-d"
    else # Default handling
      "%Y-%-m-%-d"
    end
  end

  # Initially just used by scheduled jobs display, but could be used by other things!
  def period_in_words(seconds)
    return "" if seconds.blank?

    seconds = seconds.to_i.abs
    if seconds >= 365.days
      pluralize((seconds / 31556952.0).round(1), "year")
    elsif seconds < 1.minute
      pluralize(seconds, "second")
    elsif seconds >= 1.minute && seconds < 1.hour
      pluralize((seconds / 60.0).round(1), "minute")
    elsif seconds >= 1.hour && seconds < 24.hours
      pluralize((seconds / 3600.0).round(1), "hour")
    elsif seconds >= 24.hours && seconds < 14.days
      pluralize((seconds / 86400.0).round(1), "day")
    else
      pluralize((seconds / 604800.0).round(1), "weeks")
    end.gsub(".0 ", " ") # strip out the empty zero
  end

  def organization_dashboard_bikes_graph_data
    org_registrations = {
      name: "Organization registrations created",
      data: time_range_counts(collection: @bikes_in_organizations, column: "bikes.created_at")
    }
    return [org_registrations] unless current_organization.regional?

    [
      org_registrations,
      {
        name: "Self registrations created",
        data: time_range_counts(collection: @bikes_not_in_organizations, column: "bikes.created_at")
      }
    ]
  end

  private

  def collection_grouped(collection:, column: "created_at", time_range: nil)
    time_range ||= @time_range
    # A default_scope order (Organization's name) can't sit beside the GROUP BY
    collection.unscope(:order).send(group_by_method(time_range), column, **grouping(time_range))
  end

  # Shared with empty_time_range_counts, whose whole contract is producing the same
  # buckets: range is what makes groupdate emit the empty ones
  def grouping(time_range)
    {range: time_range, format: group_by_format(time_range), time_zone: Time.zone}
  end
end
