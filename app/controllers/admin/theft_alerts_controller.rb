class Admin::TheftAlertsController < Admin::BaseController
  include SortableTable

  before_action :set_period, only: [:index]
  before_action :find_theft_alert, only: [:edit, :update]

  def index
    @theft_alerts =
      matching_theft_alerts.reorder("theft_alerts.#{sort_column} #{sort_direction}")
        .includes(:theft_alert_plan, :stolen_record)
        .page(params.fetch(:page, 1))
        .per(params.fetch(:per_page, 25))
  end

  def show
    redirect_to edit_admin_theft_alert_path
  end

  def edit
  end

  def update
    if ParamsNormalizer.boolean(params[:activate_theft_alert])
      new_data = @theft_alert.facebook_data || {}
      @theft_alert.update(facebook_data: new_data.merge(activating_at: Time.current.to_i))
      ActivateTheftAlertWorker.perform_async(@theft_alert.id)
      flash[:success] = "Activating, please wait"
      redirect_to admin_theft_alert_path(@theft_alert)
    elsif ParamsNormalizer.boolean(params[:update_theft_alert])
      UpdateTheftAlertFacebookWorker.perform_async(@theft_alert.id)
      flash[:success] = "Updating Facebook data"
      redirect_to admin_theft_alerts_path
    elsif @theft_alert.update(set_alert_timestamps(theft_alert_params))
      flash[:success] = "Success!"
      redirect_to admin_theft_alerts_path
    else
      flash[:error] = @theft_alert.errors.to_a
      render :edit
    end
  end

  helper_method :matching_theft_alerts, :available_statuses

  private

  def find_theft_alert
    @theft_alert ||= TheftAlert.find(params[:id])
    @stolen_record ||= @theft_alert.stolen_record
    @bike ||= Bike.unscoped.find(@stolen_record.bike_id)
  end

  def theft_alert_params
    params.require(:theft_alert).permit(
      :begin_at,
      :end_at,
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

  def available_statuses
    TheftAlert.statuses + ["posted"]
  end

  def matching_theft_alerts
    @search_recovered = ParamsNormalizer.boolean(params[:search_recovered])
    theft_alerts = if @search_recovered
      stolen_record_ids = StolenRecord.recovered.with_theft_alerts
        .where(theft_alerts: {created_at: @time_range}).pluck(:id)
      TheftAlert.where(stolen_record_id: stolen_record_ids)
    else
      TheftAlert
    end
    if available_statuses.include?(params[:search_status])
      @status = params[:search_status]
      theft_alerts = if @status == "posted"
        theft_alerts.posted
      else
        theft_alerts.where(status: @status)
      end
    else
      @status = "all"
    end
    if params[:user_id].present?
      @user = User.unscoped.friendly_find(params[:user_id])
      theft_alerts = theft_alerts.where(user_id: @user.id) if @user.present?
    end
    theft_alerts.where(created_at: @time_range)
  end

  # Deprecated - should be removed soon.
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
