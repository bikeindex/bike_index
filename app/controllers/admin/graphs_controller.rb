class Admin::GraphsController < Admin::BaseController
  def index
    # @graph_type = 'bikes'
    # range = date_range("2013-01-18 21:03:08")
    # @xaxis = month_list(range).to_json
    # @values1 = range_values(range, "bikes_value").to_json
    # @values2 = range_values(range, "stolen_bike_value").to_json
  end

  def users
    render json: User.group_by_week(:created_at).count
  end

  def bikes
    render json: Bike.unscoped.group_by_month(:created_at).count
  end

  def show
    @graph_type = params[:id]
    range = date_range("2013-01-18 21:03:08")
    @xaxis = month_list(range).to_json
    @values1 = range_values(range, "#{params[:id]}_value").to_json
    if params[:id] == 'bikes'
      @values2 = range_values(range, "stolen_bike_value").to_json
    end
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