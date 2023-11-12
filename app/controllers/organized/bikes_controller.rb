module Organized
  class BikesController < Organized::BaseController
    include SortableTable
    skip_before_action :set_x_frame_options_header, only: [:new_iframe, :create]
    skip_before_action :ensure_not_ambassador_organization!, only: [:multi_serial_search]

    def index
      @page = params[:page] || 1
      set_period
      @bike_sticker = BikeSticker.lookup_with_fallback(params[:bike_sticker], organization_id: current_organization.id) if params[:bike_sticker].present?
      if current_organization.enabled?("bike_search")

        @per_page = params[:per_page] || 10
        search_organization_bikes
        if current_organization.enabled?("csv_exports") && InputNormalizer.boolean(params[:create_export])
          if @bikes.count > 10_000 # Don't want everything to explode...
            flash[:error] = "Too many bikes selected to export"
          else
            export = Export.create(create_export_params)
            OrganizationExportWorker.perform_async(export.id)
            flash[:success] = "Export created"
            redirect_to organization_export_path(export, organization_id: current_organization.id)
          end
        end
      else
        @per_page = params[:per_page] || 50
        @available_bikes = if current_organization.enabled?("claimed_ownerships")
          claimed_ownerships_search
        else
          organization_bikes.where(created_at: @time_range)
        end
        @bikes = @available_bikes.order("bikes.created_at desc").page(@page).per(@per_page)
      end
    end

    def recoveries
      redirect_to(current_root_path) && return unless current_organization.enabled?("show_recoveries")
      set_period
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      # Default to showing regional recoveries
      @search_only_organization = InputNormalizer.boolean(params[:search_only_organization])
      # ... but if organization isn't regional, we can't show regional
      @search_only_organization = true unless current_organization.regional?
      recovered_records = @search_only_organization ? current_organization.recovered_records : current_organization.nearby_recovered_records

      @matching_recoveries = recovered_records.where(recovered_at: @time_range)
      @recoveries = @matching_recoveries.reorder(recovered_at: :desc).page(@page).per(@per_page)
      # When selecting through the organization bikes, it fails. Lazy solution: Don't permit doing that ;)
      @render_chart = !@search_only_organization && InputNormalizer.boolean(params[:render_chart])
    end

    def incompletes
      redirect_to(current_root_path) && return unless current_organization.enabled?("show_partial_registrations")
      set_period
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      b_params = current_organization.incomplete_b_params
      b_params = b_params.email_search(params[:query]) if params[:query].present?
      @b_params_total = b_params.where(created_at: @time_range)
      @b_params = @b_params_total.order(created_at: :desc).page(@page).per(@per_page)
    end

    def resend_incomplete_email
      redirect_to(current_root_path) && return unless current_organization.enabled?("show_partial_registrations")
      @b_param = current_organization.incomplete_b_params.find_by_id(params[:id])
      if @b_param.present?
        EmailPartialRegistrationWorker.perform_async(@b_param.id)
        flash[:success] = "Incomplete registration re-sent!"
      else
        flash[:error] = "Unable to find that incomplete bike"
      end
      redirect_back(fallback_location: incompletes_organization_bikes_path(organization_id: current_organization.id))
    end

    def new
      @unregistered_parking_notification = current_organization.enabled?("parking_notifications") && params[:parking_notification].present?
      if @unregistered_parking_notification
        @page_title = "#{current_organization.short_name} New parking notification"
      end
    end

    def new_iframe
      @organization = current_organization
      @b_param = find_or_new_b_param
      @bike = BikeCreator.new.build_bike(@b_param)
      render layout: "embed_layout"
    end

    def multi_serial_search
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
        @bike = BikeCreator.new.create_bike(@b_param)
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
      %w[id updated_by_user_at owner_email manufacturer_id frame_model cycle_type]
    end

    def organization_bikes
      current_organization.bikes.reorder("bikes.created_at desc")
    end

    def current_root_path
      organization_bikes_path(organization_id: current_organization.to_param)
    end

    def redirect_back_fallback_path
      if params[:id].present?
        bike_path(params[:id])
      else
        organization_bikes_path
      end
    end

    def claimed_ownerships_search
      bikes = organization_bikes
      if %w[transferred initial].include?(params[:search_claimedness])
        @search_claimedness = params[:search_claimedness]
        bikes = if @search_claimedness == "initial"
          bikes.joins(:ownerships).where(ownerships: {current: true, previous_ownership_id: nil})
        else
          bikes.joins(:ownerships).where.not(ownerships: {previous_ownership_id: nil})
        end
      else
        @search_claimedness = "all"
      end
      bikes.where(created_at: @time_range)
    end

    def search_organization_bikes
      @permitted_org_bike_search_params = permitted_org_bike_search_params.except(:stolenness, :timezone, :period).values.reject(&:blank?)
      @search_query_present = permitted_org_bike_search_params.except(:stolenness, :timezone, :period).values.reject(&:blank?).any?
      @interpreted_params = Bike.searchable_interpreted_params(permitted_org_bike_search_params, ip: forwarded_ip_address)
      org = current_organization || passive_organization
      if org.present?
        bikes = org.bikes.search(@interpreted_params)
        bikes = bikes.organized_email_and_name_search(params[:search_email]) if params[:search_email].present?
      else
        bikes = Bike.search(@interpreted_params)
      end
      if params[:search_stickers].present?
        @search_stickers = params[:search_stickers] == "none" ? "none" : "with"
        bikes = @search_stickers == "none" ? bikes.no_bike_sticker : bikes.bike_sticker
      else
        @search_stickers = false
      end
      if %w[none with with_street without_street].include?(params[:search_address])
        @search_address = params[:search_address]
        # Currently removed none and with - instead using street - I think that reflects people's expectations
        bikes = case @search_address
        when "none" then bikes.without_location
        when "without_street" then bikes.without_street
        when "with_street" then bikes.with_street
        when "with" then bikes.with_location
        end
      else
        @search_address = false
      end
      if search_status != "all"
        bikes = if search_status == "not_impounded"
          bikes.where.not(status: "status_impounded")
        else
          bikes.where(status: "status_#{search_status}")
        end
      end
      if params[:search_model_audit_id].present?
        @model_audit = ModelAudit.find_by_id(params[:search_model_audit_id])
        bikes = bikes.where(model_audit_id: params[:search_model_audit_id])
      end
      @available_bikes = bikes.where(created_at: @time_range) # Maybe sometime we'll do charting
      @bikes = @available_bikes.reorder("bikes.#{sort_column} #{sort_direction}").page(@page).per(@per_page)
      if @interpreted_params[:serial]
        @close_serials = organization_bikes.search_close_serials(@interpreted_params).limit(25)
      end
      @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)
    end

    def search_status
      return @search_status if defined?(@search_status)
      valid_statuses = %w[with_owner stolen all]
      valid_statuses += %w[impounded not_impounded] if current_organization.enabled?("impound_bikes")
      @search_status = valid_statuses.include?(params[:search_status]) ? params[:search_status] : valid_statuses.last
    end

    def create_export_params
      {
        kind: "organization",
        organization_id: current_organization.id,
        custom_bike_ids: @available_bikes.pluck(:id),
        only_custom_bike_ids: true,
        headers: Export.permitted_headers(current_organization),
        user_id: current_user.id
      }
    end
  end
end
