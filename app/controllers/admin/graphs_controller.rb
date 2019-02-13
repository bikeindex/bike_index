class Admin::GraphsController < Admin::BaseController
  def index
    set_variable_graph_kind
    set_variable_graphing_timing unless @kind == "general"
  end

  def variable
    set_variable_graph_kind
    set_variable_graphing_timing

    if @kind == "users"
      chart_data = User.where(created_at: @start_at..@end_at)
                       .group_by_period(@group_period, :created_at, time_zone: @timezone)
                       .count
    elsif @kind == "payments"
      chart_data = Payment.where(created_at: @start_at..@end_at)
                       .group_by_period(@group_period, :created_at, time_zone: @timezone)
                       .count
    end
    if chart_data.present?
      render json: chart_data
    else
      render json: { error: "unable to parse chart" }
    end
  end

  def tables
  end

  def users
    render json: User.group_by_month(:created_at).count
  end

  def bikes
    bikes = Bike.unscoped
    case params[:start_at]
    when 'past_year'
      range = 1.year.ago.midnight..Time.now
    else
      range ||= bike_index_start..Time.now
    end
    bgraph = [
      { name: 'Registrations', data: bikes.group_by_month(:created_at, range: range).count },
      { name: 'Stolen', data: bikes.where(stolen: true).group_by_month(:created_at, range: range).count }
    ]
    render json: bgraph.chart_json
  end

  def show
    @graph_type = params[:id]
    range = date_range('2013-01-18 21:03:08')
    @xaxis = month_list(range).to_json
    @values1 = range_values(range, "#{params[:id]}_value").to_json
    if params[:id] == 'bikes'
      @values2 = range_values(range, "stolen_bike_value").to_json
    end
  end

  def stolen_locations
  end

  def review
    start_day = (1.week.ago - 1.day).to_date
    end_day = (1.day.ago).to_date
    xaxis = []
    days_from_this_week = (start_day..end_day).map

    days_from_this_week.each do |day|
      xaxis << day.strftime("%A")

    end
    @xaxis = xaxis.to_json
  end

  protected

  # Default start time
  def bike_index_start
    Time.zone.parse('2007-01-01 1:00')
  end

  def set_variable_graph_kind
    @graph_kinds = %w[general users payments]
    @kind = @graph_kinds.include?(params[:kind]) ? params[:kind] : @graph_kinds.first
  end

  def set_variable_graphing_timing
    @timezone = TimeParser.parse_timezone(params[:timezone] || "America/Los_Angeles")
    @start_at = params[:start_at].present? ? TimeParser.parse(params[:start_at], @timezone) : bike_index_start
    @end_at = params[:end_at].present? ? TimeParser.parse(params[:end_at], @timezone) : Time.now
    @group_period = calculated_group_period(@start_at, @end_at)
  end

  def calculated_group_period(start_at, end_at)
    difference_in_seconds = (end_at - start_at).to_i
    if difference_in_seconds < 2.days.to_i
      "hour"
    elsif difference_in_seconds < 1.month.to_i
      "day"
    elsif difference_in_seconds < 1.year.to_i
      "week"
    else
      "month"
    end
  end

  def date_range(start_date)
    date_from  = Date.parse(start_date)
    date_to    = Date.today
    date_range = date_from..date_to
    date_months = date_range.map {|d| Date.new(d.year, d.month, 1) }.uniq
  end

  def month_list(range)
    range.map {|d| d.strftime "%B" }
  end

  def range_values(range, type)
    values = []
    range.each do |date|
      values << self.send(type, date)
    end
    values
  end

  def bikes_value(date)
    Ownership.where(["created_at < ?", date.end_of_month.end_of_day]).count
  end

  def stolen_bike_value(date)
    Bike.where(["created_at < ?", date.end_of_month.end_of_day]).stolen.count
  end

  def users_value(date)
    User.where(["created_at < ?", date.end_of_month.end_of_day]).count
  end

  def organizations_value(date)
    Organization.where(["created_at < ?", date.end_of_month.end_of_day]).count
  end
end
