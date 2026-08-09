module Admin
  class TheftAlertsController < Admin::BaseController
    include Binxtils::SortableTable

    before_action :find_promoted_alert, only: [:edit, :update]

    def index
      @per_page = permitted_per_page
      @pagy, @promoted_alerts =
        pagy(:countish, searched_promoted_alerts.reorder("promoted_alerts.#{sort_column} #{sort_direction}")
          .includes(:theft_alert_plan, :stolen_record), limit: @per_page, page: permitted_page)
      @page_title = "Admin | Promoted alerts"
      @location_counts = Binxtils::InputNormalizer.boolean(params[:search_location_counts])
    end

    def show
      redirect_to edit_admin_theft_alert_path
    end

    def edit
    end

    def update
      if Binxtils::InputNormalizer.boolean(params[:activate_theft_alert])
        new_data = @promoted_alert.facebook_data || {}
        @promoted_alert.update(facebook_data: new_data.merge(activating_at: Time.current.to_i))
        BikeJobs::ActivateTheftAlertJob.perform_async(@promoted_alert.id, true)
        flash[:success] = "Activating, please wait"
        redirect_to admin_theft_alert_path(@promoted_alert)
      elsif Binxtils::InputNormalizer.boolean(params[:update_theft_alert])
        BikeJobs::UpdateTheftAlertFacebookJob.new.perform(@promoted_alert.id)
        flash[:success] = "Updating Facebook data"
        redirect_to admin_theft_alerts_path
      elsif @promoted_alert.update(permitted_update_params)
        flash[:success] = "Success!"
        redirect_to admin_theft_alerts_path
      else
        flash[:error] = @promoted_alert.errors.full_messages.to_sentence
        render :edit
      end
    end

    def new
      @bike = Bike.unscoped.find_by_id(params[:bike_id])
      unless @bike.present?
        flash[:notice] = "Unable to find that bike. Select a bike to create a new promoted alert"
        redirect_to admin_theft_alerts_path
        return
      end
      @stolen_record = @bike.current_stolen_record
      @promoted_alerts = @stolen_record&.promoted_alerts || []

      @theft_alert_plans = TheftAlertPlan.active.price_ordered_asc.in_language(I18n.locale)

      @promoted_alert = PromotedAlert.new(stolen_record: @stolen_record,
        theft_alert_plan: @theft_alert_plans.first,
        user: current_user,
        admin: true)
      @promoted_alert.set_calculated_attributes # Set some stuff
    end

    def create
      @promoted_alert = PromotedAlert.new(permitted_create_params)
      if @promoted_alert.save
        BikeJobs::ActivateTheftAlertJob.perform_async(@promoted_alert.id) if @promoted_alert.activateable?
        flash[:success] = "Promoted alert created!"
        redirect_to edit_admin_theft_alert_path(@promoted_alert)
      else
        render :new
      end
    end

    helper_method :searched_promoted_alerts, :available_statuses, :available_paid_admin

    private

    def find_promoted_alert
      @promoted_alert ||= PromotedAlert.find_alert(params[:id])
      @stolen_record ||= @promoted_alert.stolen_record
      @bike ||= Bike.unscoped.find_id(@stolen_record.bike_id)
    end

    def permitted_update_params
      params.require(:promoted_alert).permit(:notes)
    end

    def permitted_create_params
      params.require(:promoted_alert).permit(:notes,
        :stolen_record_id,
        :ad_radius_miles,
        :theft_alert_plan_id)
        .merge(user: current_user, admin: true)
    end

    # Override, set one week before earliest created promoted alert
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
      PromotedAlert.statuses + %w[posted failed_to_activate]
    end

    def available_paid_admin
      %w[paid_or_admin paid admin unpaid paid_and_unpaid]
    end

    def searched_promoted_alerts
      @search_recovered = Binxtils::InputNormalizer.boolean(params[:search_recovered])
      promoted_alerts = if @search_recovered
        stolen_record_ids = StolenRecord.recovered.with_promoted_alerts
          .where(promoted_alerts: {created_at: @time_range}).pluck(:id)
        PromotedAlert.where(stolen_record_id: stolen_record_ids)
      else
        PromotedAlert
      end
      if params[:user_id].present?
        promoted_alerts = promoted_alerts.where(user_id: user_subject&.id || params[:user_id])
      end
      if params[:search_bike_id].present?
        @bike = Bike.unscoped.friendly_find(params[:search_bike_id])
        promoted_alerts = promoted_alerts.where(bike_id: @bike.id) if @bike.present?
      end
      @search_paid_admin = if available_paid_admin.include?(params[:search_paid_admin])
        params[:search_paid_admin]
      elsif user_subject.present? || @bike.present?
        "paid_and_unpaid" # by default, include all paid and unpaid if user or bike is searched
      else
        available_paid_admin.first
      end
      # paid_and_unpaid is "all"
      promoted_alerts = promoted_alerts.public_send(@search_paid_admin) if @search_paid_admin != "paid_and_unpaid"

      @search_facebook_data = Binxtils::InputNormalizer.boolean(params[:search_facebook_data])
      promoted_alerts = promoted_alerts.facebook_updateable if @search_facebook_data

      if available_statuses.include?(params[:search_status])
        @status = params[:search_status]
        promoted_alerts = if PromotedAlert.statuses.include?(@status)
          promoted_alerts.where(status: @status)
        else # It must be one of the special statuses - which must be valid to send!
          promoted_alerts.send(@status)
        end
      else
        @status = "all"
      end
      # We always render distance
      @distance = GeocodeHelper.permitted_distance(params[:search_distance], default_distance: 50)
      if params[:search_location].present?
        bounding_box = GeocodeHelper.bounding_box(params[:search_location], @distance)
        promoted_alerts = promoted_alerts.within_bounding_box(bounding_box)
      end

      # Only handling created_at now
      @time_range_column ||= "created_at"
      promoted_alerts.where(@time_range_column => @time_range)
    end

    # Deprecated - should be removed soon.
    def set_alert_timestamps(promoted_alert_attrs)
      currently_pending = @promoted_alert.status == "pending"
      transitioning_to_active = promoted_alert_attrs[:status] == "active"
      transitioning_to_pending = promoted_alert_attrs[:status] == "pending"

      if currently_pending && transitioning_to_active
        theft_alert_plan = TheftAlertPlan.find(promoted_alert_attrs[:theft_alert_plan_id])
        now = Time.current
        promoted_alert_attrs[:start_at] = now
        promoted_alert_attrs[:end_at] = now + theft_alert_plan.duration_days.days
      elsif transitioning_to_pending
        promoted_alert_attrs[:start_at] = nil
        promoted_alert_attrs[:end_at] = nil
      else
        timezone = Binxtils::TimeZoneParser.parse(params[:timezone])
        promoted_alert_attrs[:start_at] = Binxtils::TimeParser.parse(promoted_alert_attrs[:start_at], timezone)
        promoted_alert_attrs[:end_at] = Binxtils::TimeParser.parse(promoted_alert_attrs[:end_at], timezone)
      end

      promoted_alert_attrs
    end
  end
end
