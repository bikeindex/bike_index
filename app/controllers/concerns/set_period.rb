# frozen_string_literal: true

module SetPeriod
  extend ActiveSupport::Concern
  DEFAULT_EARLIEST_TIME = Date.parse("2024-1-1").freeze
  PERIOD_TYPES = %w[hour day month year week all next_week next_month].freeze

  # For setting periods, particularly for graphing
  def set_period
    set_timezone
    # Set time period
    @period ||= params[:period]
    if @period == "custom"
      if params[:start_time].present?
        @start_time = TimeParser.parse(params[:start_time], @timezone)
        @end_time = TimeParser.parse(params[:end_time], @timezone) || Time.current

        @start_time, @end_time = @end_time, @start_time if @start_time > @end_time
      else
        set_time_range_from_period
      end
    elsif params[:search_at].present?
      @period = "custom"
      @search_at = TimeParser.parse(params[:search_at], @timezone)
      offset = params[:period].present? ? params[:period].to_i : 10.minutes.to_i
      @start_time = @search_at - offset
      @end_time = @search_at + offset
    else
      set_time_range_from_period
    end

    # Add this render_chart in here so we don't have to define it in all the controllers
    @render_chart = ActiveRecord::Type::Boolean.new.cast(params[:render_chart].to_s.strip)
    @time_range = @start_time..@end_time
  end

  private

  def set_time_range_from_period
    @period = default_period unless PERIOD_TYPES.include?(@period)

    case @period
    when "hour"
      @start_time = Time.current - 1.hour
    when "day"
      @start_time = Time.current.beginning_of_day - 1.day
    when "month"
      @start_time = Time.current.beginning_of_day - 30.days
    when "year"
      @start_time = Time.current.beginning_of_day - 1.year
    when "week"
      @start_time = Time.current.beginning_of_day - 1.week
    when "next_month"
      @start_time ||= Time.current
      @end_time = Time.current.beginning_of_day + 30.days
    when "next_week"
      @start_time = Time.current
      @end_time = Time.current.beginning_of_day + 1.week
    when "all"
      @start_time = earliest_period_date
    end
    @end_time ||= latest_period_date
  end

  # Separate method so it can be overridden on per controller basis
  def default_period
    "all"
  end

  # Separate method so it can be overriden
  def latest_period_date
    Time.current
  end

  def set_timezone
    return true if @timezone.present?

    # Parse the timezone params if they are passed (tested in admin#activity_groups#index)
    if params[:timezone].present?
      @timezone = TimeParser.parse_timezone(params[:timezone])
      # If it's a valid timezone, save to session
      session[:timezone] = @timezone&.name
    end

    # Set the timezone on a per request basis if we have a timezone saved
    if session[:timezone].present?
      @timezone ||= TimeParser.parse_timezone(session[:timezone])
      Time.zone = @timezone
    end

    @timezone ||= TimeParser::DEFAULT_TIME_ZONE
  end

  def earliest_period_date
    DEFAULT_EARLIEST_TIME
  end
end
