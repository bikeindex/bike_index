class GraphsController < ApplicationController
  def index

  end

  def show
    @graph_type = params[:id]
    range = date_range("2013-01-18 21:03:08")
    @xaxis = month_list(range).to_json
    @values1 = range_values(range, "ownership_value").to_json
    @values2 = range_values(range, "stolen_bike_value").to_json
    # @values1 = range_values(range, "user_value").to_json
    # @values2 = range_values(range, "organization_value").to_json
    render :layout => 'graphs'
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

  def ownership_value(date)
    Ownership.where(["created_at < ?", date.end_of_month.end_of_day]).count
  end

  def stolen_bike_value(date)
    Bike.where(["created_at < ?", date.end_of_month.end_of_day]).stolen.count
  end

  def user_value(date)
    User.where(["created_at < ?", date.end_of_month.end_of_day]).count
  end

  def organization_value(date)
    Organization.where(["created_at < ?", date.end_of_month.end_of_day]).count
  end

end