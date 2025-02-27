class Admin::TheftAlertsController < Admin::BaseController
  include SortableTable

  before_action :find_theft_alert, only: [:edit, :update]

  def index
    @per_page = params[:per_page] || 25
    @pagy, @theft_alerts =
      pagy(searched_theft_alerts.reorder("theft_alerts.#{sort_column} #{sort_direction}")
        .includes(:theft_alert_plan, :stolen_record), limit: @per_page)
    @page_title = "Admin | Promoted alerts"
    @location_counts = InputNormalizer.boolean(params[:search_location_counts])
  end

  def show
    redirect_to edit_admin_theft_alert_path
  end

  def edit
  end

  def update
    if InputNormalizer.boolean(params[:activate_theft_alert])
      new_data = @theft_alert.facebook_data || {}
      @theft_alert.update(facebook_data: new_data.merge(activating_at: Time.current.to_i))
      StolenBike::ActivateTheftAlertJob.perform_async(@theft_alert.id, true)
      flash[:success] = "Activating, please wait"
      redirect_to admin_theft_alert_path(@theft_alert)
    elsif InputNormalizer.boolean(params[:update_theft_alert])
      StolenBike::UpdateTheftAlertFacebookJob.new.perform(@theft_alert.id)
      flash[:success] = "Updating Facebook data"
      redirect_to admin_theft_alerts_path
    elsif @theft_alert.update(permitted_update_params)
      flash[:success] = "Success!"
      redirect_to admin_theft_alerts_path
    else
      flash[:error] = @theft_alert.errors.to_a
      render :edit
    end
  end

  def new
    @bike = Bike.unscoped.find_by_id(params[:bike_id])
    unless @bike.present?
      flash[:info] = "Unable to find that bike. Select a bike to create a new promoted alert"
      redirect_to admin_theft_alerts_path
      return
    end
    @stolen_record = @bike.current_stolen_record
    @theft_alerts = @stolen_record&.theft_alerts || []

    bike_image = PublicImage.find_by(id: params[:selected_bike_image_id])
    @bike.current_stolen_record.generate_alert_image(bike_image: bike_image)

    @theft_alert_plans = TheftAlertPlan.active.price_ordered_asc.in_language(I18n.locale)

    @theft_alert = TheftAlert.new(stolen_record: @stolen_record,
      theft_alert_plan: @theft_alert_plans.first,
      user: current_user,
      admin: true)
    @theft_alert.set_calculated_attributes # Set some stuff
  end

  def create
    @theft_alert = TheftAlert.new(permitted_create_params)
    if @theft_alert.save
      StolenBike::ActivateTheftAlertJob.perform_async(@theft_alert.id) if @theft_alert.activateable?
      flash[:success] = "Promoted alert created!"
      redirect_to edit_admin_theft_alert_path(@theft_alert)
    else
      render :new
    end
  end

  helper_method :searched_theft_alerts, :available_statuses, :available_paid_admin

  private

  def find_theft_alert
    @theft_alert ||= TheftAlert.find(params[:id])
    @stolen_record ||= @theft_alert.stolen_record
    @bike ||= Bike.unscoped.find(@stolen_record.bike_id)
  end

  def permitted_update_params
    params.require(:theft_alert).permit(:notes)
  end

  def permitted_create_params
    params.require(:theft_alert).permit(:notes,
      :stolen_record_id,
      :ad_radius_miles,
      :theft_alert_plan_id)
      .merge(user: current_user, admin: true)
  end

  # Override, set one week before earliest created theft alert
  def earliest_period_date
    if @search_facebook_data
      Time.at(1624982189)
    else
      Time.at(1560805519)
    end
  end

  def sortable_columns
    %w[created_at theft_alert_plan_id amount_cents_facebook_spent reach status start_at end_at]
  end

  def available_statuses
    TheftAlert.statuses + %w[posted failed_to_activate]
  end

  def available_paid_admin
    %w[paid_or_admin paid admin unpaid paid_and_unpaid]
  end

  def searched_theft_alerts
    @search_recovered = InputNormalizer.boolean(params[:search_recovered])
    theft_alerts = if @search_recovered
      stolen_record_ids = StolenRecord.recovered.with_theft_alerts
        .where(theft_alerts: {created_at: @time_range}).pluck(:id)
      TheftAlert.where(stolen_record_id: stolen_record_ids)
    else
      TheftAlert
    end
    @search_paid_admin = if available_paid_admin.include?(params[:search_paid_admin])
      params[:search_paid_admin]
    else
      available_paid_admin.first
    end
    # paid_and_unpaid is "all"
    theft_alerts = theft_alerts.public_send(@search_paid_admin) if @search_paid_admin != "paid_and_unpaid"

    @search_facebook_data = InputNormalizer.boolean(params[:search_facebook_data])
    theft_alerts = theft_alerts.facebook_updateable if @search_facebook_data
    if available_statuses.include?(params[:search_status])
      @status = params[:search_status]
      theft_alerts = if TheftAlert.statuses.include?(@status)
        theft_alerts.where(status: @status)
      else # It must be one of the special statuses - which must be valid to send!
        theft_alerts.send(@status)
      end
    else
      @status = "all"
    end
    if params[:user_id].present?
      @user = User.unscoped.friendly_find(params[:user_id])
      theft_alerts = theft_alerts.where(user_id: @user.id) if @user.present?
    end
    if params[:search_bike_id].present?
      @bike = Bike.unscoped.friendly_find(params[:search_bike_id])
      theft_alerts = theft_alerts.where(bike_id: @bike.id) if @bike.present?
    end
    # We always render distance
    distance = params[:search_distance].to_i
    @distance = (distance.present? && distance > 0) ? distance : 50
    if params[:search_location].present?
      bounding_box = GeocodeHelper.bounding_box(params[:search_location], @distance)
      theft_alerts = theft_alerts.within_bounding_box(bounding_box)
    end

    # Only handling created_at now
    @time_range_column ||= "created_at"
    theft_alerts.where(@time_range_column => @time_range)
  end

  # Deprecated - should be removed soon.
  def set_alert_timestamps(theft_alert_attrs)
    currently_pending = @theft_alert.status == "pending"
    transitioning_to_active = theft_alert_attrs[:status] == "active"
    transitioning_to_pending = theft_alert_attrs[:status] == "pending"

    if currently_pending && transitioning_to_active
      theft_alert_plan = TheftAlertPlan.find(theft_alert_attrs[:theft_alert_plan_id])
      now = Time.current
      theft_alert_attrs[:start_at] = now
      theft_alert_attrs[:end_at] = now + theft_alert_plan.duration_days.days
    elsif transitioning_to_pending
      theft_alert_attrs[:start_at] = nil
      theft_alert_attrs[:end_at] = nil
    else
      timezone = TimeZoneParser.parse(params[:timezone])
      theft_alert_attrs[:start_at] = TimeParser.parse(theft_alert_attrs[:start_at], timezone)
      theft_alert_attrs[:end_at] = TimeParser.parse(theft_alert_attrs[:end_at], timezone)
    end

    theft_alert_attrs
  end
end
