class Admin::BaseController < ApplicationController
  before_filter :require_index_admin!
  layout "admin"

  def set_period
    @period = params[:period]
    case @period
    when "hour"
      @start_time = Time.now - 1.hour
    when "day"
      @start_time = Time.now - 1.day
    when "month"
      @start_time = Time.now - 30.days
    when "year"
      @start_time = Time.now - 1.year
    when "all"
      if current_organization.present?
        @start_time = current_organization.created_at
      else
        @start_time = Time.at(1134972000) # Earliest bike created at
      end
    else
      @period = "week"
      @start_time = Time.now - 7.days
    end
    @time_range = @start_time..Time.now
  end
end
