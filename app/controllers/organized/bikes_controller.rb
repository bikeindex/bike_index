module Organized
  class BikesController < Organized::BaseController
    include Binxtils::SortableTable

    SORTABLE_COLUMNS = %w[id updated_by_user_at owner_email mnfg_name frame_model cycle_type propulsion_type]

    # index moved to RegistrationsController; remove the SortableTable set_period
    # callback that targets :index (Rails 7.1 raises on missing callback actions)
    skip_before_action :set_period
    before_action :allow_x_frame, only: [:new_iframe, :create]

    def recoveries
      redirect_to(current_root_path) && return unless current_organization.enabled?("show_recoveries")

      set_period
      @per_page = permitted_per_page
      # Default to showing regional recoveries
      @search_only_organization = Binxtils::InputNormalizer.boolean(params[:search_only_organization])
      # ... but if organization isn't regional, we can't show regional
      @search_only_organization = true unless current_organization.regional?
      recovered_records = @search_only_organization ? current_organization.recovered_records : current_organization.nearby_recovered_records

      @matching_recoveries = recovered_records.where(recovered_at: @time_range)
      @pagy, @recoveries = pagy(:countish, @matching_recoveries.reorder(recovered_at: :desc), limit: @per_page, page: permitted_page)
      # When selecting through the organization bikes, it fails. Lazy solution: Don't permit doing that ;)
      @render_chart = !@search_only_organization && Binxtils::InputNormalizer.boolean(params[:render_chart])
    end

    def incompletes
      redirect_to(current_root_path) && return unless current_organization.enabled?("show_partial_registrations")

      set_period
      @per_page = permitted_per_page
      b_params = current_organization.incomplete_b_params
      b_params = b_params.email_search(params[:query]) if params[:query].present?

      @b_params_total = incompletes_sorted(b_params.where(created_at: @time_range))
      @pagy, @b_params = pagy(:countish, @b_params_total, limit: @per_page, page: permitted_page)
    end

    def resend_incomplete_email
      redirect_to(current_root_path) && return unless current_organization.enabled?("show_partial_registrations")

      @b_param = current_organization.incomplete_b_params.find_by_id(params[:id])
      if @b_param.present?
        Email::PartialRegistrationJob.perform_async(@b_param.id)
        flash[:success] = "Incomplete registration re-sent!"
      else
        flash[:error] = "Unable to find that incomplete bike"
      end
      redirect_back(fallback_location: incompletes_organization_bikes_path(organization_id: current_organization.id))
    end

    def new
      unless current_organization.auto_user.present?
        flash[:error] = "You need to specify an email for your 'registration email' to be sent from"
        redirect_to(organization_manage_path(organization_id: current_organization.to_param)) && return
      end

      @unregistered_parking_notification = current_organization.enabled?("parking_notifications") && params[:parking_notification].present?
      if @unregistered_parking_notification
        @page_title = "#{current_organization.short_name} New parking notification"
      end
    end

    def new_iframe
      @organization = current_organization
      @b_param = find_or_new_b_param
      @bike = BikeServices::Builder.build(@b_param)
      render layout: "embed_layout"
    end

    def update
      bike = Bike.unscoped.find(params[:id])

      unless bike.organized?(current_organization) && current_organization.enabled?("registration_notes")
        flash[:error] = "Not authorized to update notes"
        redirect_to(bike_path(bike)) && return
      end

      BikeOrganizationNote.upsert(bike:, organization: current_organization, body: params[:notes], user: current_user)

      flash[:success] = "Note saved"
      redirect_to bike_path(bike)
    end

    def create
      @b_param = find_or_new_b_param
      iframe_redirect_params = {organization_id: current_organization.to_param}
      if @b_param.created_bike.present?
        flash[:success] = "#{@bike.created_bike.type} Created"
      else
        if params.dig(:bike, :image).present? # Have to do in the controller, before assigning
          @b_param.image = params[:bike].delete(:image) if params.dig(:bike, :image).present?
        end
        # we handle filtering & coercion in BParam, just create it with whatever here
        @b_param.update(permitted_create_params)
        @bike = BikeServices::Creator.new.create_bike(@b_param)
        if @bike.errors.any?
          flash[:error] = @b_param.bike_errors.to_sentence
          iframe_redirect_params[:b_param_id_token] = @b_param.id_token
        elsif @bike.parking_notifications.any? # Bike created successfully
          flash[:success] = "Parking notification created for #{@bike.type}"
        else # Bike created successfully
          flash[:success] = "#{@bike.type_titleize} Created"
        end
      end
      redirect_back(fallback_location: new_iframe_organization_bikes_path(iframe_redirect_params))
    end

    private

    def find_or_new_b_param
      token = params[:b_param_token]
      token ||= params[:bike] && params[:bike][:b_param_id_token]
      b_param = BParam.find_or_new_from_token(token, user_id: current_user&.id, organization_id: current_organization.id)
      b_param.origin = "organization_form"
      b_param
    end

    # TODO: make this less gross
    def permitted_create_params
      phash = params.as_json
      {
        origin: "organization_form",
        params: phash.merge("bike" => phash["bike"].merge("creation_organization_id" => current_organization.id))
      }
    end

    def sortable_columns
      SORTABLE_COLUMNS + %w[email motorized] # incompletes/b_param specific
    end

    def incompletes_sorted(b_params)
      if sort_column == "cycle_type"
        if sort_direction == "desc"
          b_params.cycle_type_not_bike_ordered
        else
          b_params.cycle_type_bike
        end
      elsif sort_column == "motorized"
        # NOTE: don't have a 'not_motorized' scope - it would be complicated and I don't think it's desired
        b_params.motorized
      else
        @sort_column = "id" unless %w[id email].include?(sort_column)

        b_params.order("b_params.#{sort_column} #{sort_direction}")
      end
    end

    def organization_bikes
      current_organization.bikes.reorder("bikes.created_at desc")
    end

    def current_root_path
      organization_registrations_path(organization_id: current_organization.to_param)
    end
  end
end
