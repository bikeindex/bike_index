class Admin::TheftAlertsController < Admin::BaseController
  include SortableTable

  before_action :set_period, only: [:index]
  before_action :find_theft_alert, only: [:edit, :update]

  def index
    @render_chart = ParamsNormalizer.boolean(params[:render_chart])
    @theft_alerts =
      matching_theft_alerts.reorder("theft_alerts.#{sort_column} #{sort_direction}")
        .includes(:theft_alert_plan)
        .page(params.fetch(:page, 1))
        .per(params.fetch(:per_page, 25))
  end

  def show; redirect_to edit_admin_theft_alert_path end

  def edit; end

  def update
    if @theft_alert.update(set_alert_timestamps(theft_alert_params))
      flash[:success] = "Success!"
      redirect_to admin_theft_alerts_path
    else
      flash[:error] = @theft_alert.errors.to_a
      render :edit
    end
  end

  helper_method :matching_theft_alerts

  private

  def find_theft_alert
    @theft_alert ||= TheftAlert.find(params[:id])
    @stolen_record ||= @theft_alert.stolen_record
    @bike ||= @stolen_record.bike.decorate
  end

  def theft_alert_params
    params.require(:theft_alert).permit(
      :begin_at,
      :end_at,
      :facebook_post_url,
      :notes,
      :status,
      :theft_alert_plan_id
    )
  end

  # Override, set one week before earliest created theft alert
  def earliest_period_date
    Time.at(1560805519)
  end

  def sortable_columns
    %w[created_at theft_alert_plan_id status begin_at end_at]
  end

  def matching_theft_alerts
    return @matching_theft_alerts if defined?(@matching_theft_alerts)
    @matching_theft_alerts = TheftAlert.where(created_at: @time_range)
  end

  def set_alert_timestamps(theft_alert_attrs)
    currently_pending = @theft_alert.status == "pending"
    transitioning_to_active = theft_alert_attrs[:status] == "active"
    transitioning_to_pending = theft_alert_attrs[:status] == "pending"

    if currently_pending && transitioning_to_active
      theft_alert_plan = TheftAlertPlan.find(theft_alert_attrs[:theft_alert_plan_id])
      now = Time.current
      theft_alert_attrs[:begin_at] = now
      theft_alert_attrs[:end_at] = now + theft_alert_plan.duration_days.days
    elsif transitioning_to_pending
      theft_alert_attrs[:begin_at] = nil
      theft_alert_attrs[:end_at] = nil
    else
      timezone = TimeParser.parse_timezone(params[:timezone])
      theft_alert_attrs[:begin_at] = TimeParser.parse(theft_alert_attrs[:begin_at], timezone)
      theft_alert_attrs[:end_at] = TimeParser.parse(theft_alert_attrs[:end_at], timezone)
    end

    theft_alert_attrs
  end
end
