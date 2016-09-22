class Admin::GraphsController < Admin::BaseController
  def index
    redirect_to tables_admin_graphs_path if params[:tables]
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

  def bike_index_start
    Time.zone.parse('2007-01-01 1:00')
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
