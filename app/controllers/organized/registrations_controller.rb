module Organized
  class RegistrationsController < Organized::BaseController
    include Binxtils::SortableTable

    SORTABLE_COLUMNS = %w[id updated_by_user_at owner_email mnfg_name frame_model cycle_type propulsion_type]

    skip_before_action :ensure_not_ambassador_organization!, only: [:multi_search, :multi_search_response, :multi_search_sticker_response]
    around_action :set_reading_role, only: [:multi_search_response, :multi_search_sticker_response]

    def index
      set_period
      @bike_sticker = BikeSticker.lookup_with_fallback(params[:bike_sticker], organization_id: current_organization.id) if params[:bike_sticker].present?

      if current_organization.enabled?("bike_search")
        @search_claimedness = "all"
        @render_results = Binxtils::InputNormalizer.boolean(params[:search_no_js]) || turbo_request?
        @search_query_present = permitted_org_registration_search_params.except(:stolenness, :timezone, :period).values.reject(&:blank?).any?
        @interpreted_params = BikeSearchable.searchable_interpreted_params(permitted_org_registration_search_params, ip: forwarded_ip_address)
        @selected_query_items_options = BikeSearchable.selected_query_items_options(@interpreted_params)
        @per_page = permitted_per_page(default: 10)

        if create_export?
          search_organization_bikes
          create_export_and_redirect
        elsif @render_results
          search_organization_bikes
          respond_to do |format|
            format.html { render :search }
            format.turbo_stream
          end
        else
          set_search_filter_params
          render :search
        end
      else
        @per_page = permitted_per_page(default: 50)
        @available_bikes = if current_organization.enabled?("claimed_ownerships")
          claimed_ownerships_search
        else
          organization_bikes.where(created_at: @time_range)
        end
        @pagy, @bikes = pagy(:countish, @available_bikes.order("bikes.created_at desc"), limit: @per_page, page: permitted_page)
      end
    end

    def multi_search
    end

    def multi_search_response
      @serial = params[:serial].to_s.strip
      @chip_id = params[:chip_id].to_s.strip.presence
      return head(:bad_request) unless @serial.present?

      @interpreted_params = BikeSearchable.searchable_interpreted_params({serial: @serial, stolenness: "all"}, ip: forwarded_ip_address)
      bikes = current_organization.bikes.search(@interpreted_params)
      @per_page = 10
      @pagy, @bikes = pagy(:countish, bikes.reorder("bikes.id desc"), limit: @per_page, page: permitted_page)
      @close_serials = current_organization.bikes.search_close_serials(@interpreted_params).limit(25) if @bikes.none?
    end

    def multi_search_sticker_response
      @query = params[:query].to_s.strip
      @chip_id = params[:chip_id].to_s.strip.presence
      return head(:bad_request) unless @query.present?

      @per_page = 10
      bike_ids = current_organization.bike_stickers.sticker_code_search(@query).where.not(bike_id: nil).select(:bike_id)
      bikes = Bike.where(id: bike_ids)
      @pagy, @bikes = pagy(:countish, bikes.reorder("bikes.id desc"), limit: @per_page, page: permitted_page)
    end

    private

    def sortable_columns
      SORTABLE_COLUMNS
    end

    def organization_bikes
      current_organization.bikes.reorder("bikes.created_at desc")
    end

    def current_root_path
      organization_registrations_path(organization_id: current_organization.to_param)
    end

    # NOTE: Make sure to add any custom search params to no_org_search_params?
    def search_organization_bikes
      org = current_organization || passive_organization
      if org.present?
        bikes = org.bikes.search(@interpreted_params)
        bikes = BikeServices::OrganizedSearch.email_and_name(bikes, params[:search_email])
        bikes = BikeServices::OrganizedSearch.notes(bikes, params[:search_notes], org) if params[:search_notes].present?
      else
        bikes = Bike.search(@interpreted_params)
      end
      if params[:search_stickers].present?
        @search_stickers = (params[:search_stickers] == "none") ? "none" : "with"
        bikes = (@search_stickers == "none") ? bikes.no_bike_sticker : bikes.bike_sticker
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
      @pagy, @bikes = pagy(:countish, @available_bikes.reorder("bikes.#{sort_column} #{sort_direction}"), limit: @per_page, page: permitted_page)
      if @interpreted_params[:serial]
        @close_serials = organization_bikes.search_close_serials(@interpreted_params).limit(25)
      end
    end

    # Set filter params for settings component on initial (non-turbo) page load
    def set_search_filter_params
      @search_stickers = if params[:search_stickers].present?
        (params[:search_stickers] == "none") ? "none" : "with"
      else
        false
      end
      @search_address = %w[none with with_street without_street].include?(params[:search_address]) ? params[:search_address] : false
      search_status
    end

    def search_status
      return @search_status if defined?(@search_status)

      valid_statuses = %w[with_owner stolen all]
      valid_statuses += %w[impounded not_impounded] if current_organization.enabled?("impound_bikes")
      @search_status = valid_statuses.include?(params[:search_status]) ? params[:search_status] : valid_statuses.last
    end

    def create_export?
      current_organization.enabled?("csv_exports") && Binxtils::InputNormalizer.boolean(params[:create_export])
    end

    def create_export_and_redirect
      if no_org_search_params? && no_interpreted_params?
        flash[:error] = "No bikes selected. This export will contain all your bikes"
        redirect_to new_organization_export_path(new_export_params)
        return
      end

      bikes_count = @available_bikes.count
      if bikes_count > 10_000 # Don't want everything to explode...
        flash.now[:error] = "Too many bikes selected to export"
      elsif directly_create_export?(bikes_count)
        # There is probably a better way to handle this, via storing in session or building the export but not starting
        # ... but, this works
        flash[:info] = "Directly creating export - can't configure with over 500 bikes"
        export = Export.create(create_export_params)
        OrganizationExportJob.perform_async(export.id)
        redirect_to organization_export_path(export, organization_id: current_organization.id)
      else
        if bikes_count == 0
          flash[:error] = "There are no matching bikes!"
        elsif bikes_count > 200
          flash[:info] = "Warning: Exporting from search with this many matching bikes may not work correctly"
        end
        redirect_to new_organization_export_path(new_export_params_custom_bike_ids)
      end
    end

    def no_org_search_params?
      return false if params[:search_stickers].present? && params[:search_stickers] != "all"

      params.slice(:search_address, :search_email, :search_model_audit_id, :search_notes, :search_status)
        .values.reject(&:blank?).none?
    end

    def no_interpreted_params?
      # TODO: Enable stolenness for export selection
      return false if @interpreted_params[:stolenness]&.downcase != "all"

      @interpreted_params.except(:stolenness).values.reject(&:blank?).none?
    end

    def directly_create_export?(bikes_count)
      Binxtils::InputNormalizer.boolean(params[:directly_create_export]) || bikes_count > 500
    end

    def new_export_params
      time_params = if @period == "all"
        {}
      else
        {start_at: @start_time.to_i, end_at: @end_time.to_i}
      end
      {organization_id: current_organization.id}.merge(time_params)
    end

    def new_export_params_custom_bike_ids
      {
        organization_id: current_organization.id,
        only_custom_bike_ids: true,
        custom_bike_ids: @available_bikes.pluck(:id).join("_") # Use _ because it doesn't get encoded
      }
    end

    def create_export_params
      new_export_params_custom_bike_ids.merge(kind: "organization",
        headers: Export.permitted_headers(current_organization),
        user_id: current_user.id)
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
      end
      bikes.where(created_at: @time_range)
    end
  end
end
