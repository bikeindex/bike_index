module Organized
  class BikesController < Organized::BaseController
    include SortableTable
    skip_before_action :ensure_not_ambassador_organization!, only: [:multi_serial_search]

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @bike_sticker = BikeSticker.lookup_with_fallback(params[:bike_sticker], organization_id: current_organization.id) if params[:bike_sticker].present?
      if current_organization.enabled?("bike_search")
        search_organization_bikes
      else
        @bikes = organization_bikes.order("bikes.created_at desc").page(@page).per(@per_page)
      end
    end

    def recoveries
      redirect_to current_index_path and return unless current_organization.enabled?("show_recoveries")
      set_period
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      # Default to showing regional recoveries
      @search_only_organization = ParamsNormalizer.boolean(params[:search_only_organization])
      # ... but if organization isn't regional, we can't show regional
      @search_only_organization = true unless current_organization.regional?
      recovered_records = @search_only_organization ? current_organization.recovered_records : current_organization.nearby_recovered_records

      @matching_recoveries = recovered_records.where(recovered_at: @time_range)
      @recoveries = @matching_recoveries.reorder(recovered_at: :desc).page(@page).per(@per_page)
      # When selecting through the organization bikes, it fails. Lazy solution: Don't permit doing that ;)
      @render_chart = !@search_only_organization && ParamsNormalizer.boolean(params[:render_chart])
    end

    def incompletes
      redirect_to current_index_path and return unless current_organization.enabled?("show_partial_registrations")
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      b_params = current_organization.incomplete_b_params
      b_params = b_params.email_search(params[:query]) if params[:query].present?
      @b_params = b_params.order(created_at: :desc).page(@page).per(@per_page)
    end

    def new
      @kind = params[:kind] == "abandoned" ? "abandoned" : "normal"
    end

    def new_iframe
      @organization = current_organization
      @b_param = find_or_new_b_param
      @bike = BikeCreator.new(@b_param).build_bike
      render layout: "embed_layout"
    end

    def multi_serial_search; end

    def update
      if params.dig(:bike, :impound)
        if current_organization.enabled?("impound_bikes")
          bike = Bike.find(params[:id])
          impound_record = bike.impound(current_user, organization: current_organization)
          if impound_record.valid?
            flash[:success] = translation(:bike_impounded, bike_type: bike.type)
          else
            flash[:error] = translation(:unable_to_impound,
                                        bike_type: bike.type,
                                        errors: impound_record.errors.full_messages.to_sentence)
          end
        else
          flash[:error] = translation(:your_org_not_permitted_to_impound)
        end
      else
        flash[:error] = translation(:unknown_update_action)
      end

      redirect_back(fallback_location: redirect_back_fallback_path)
    end

    def create
      @b_param = find_or_new_b_param
      iframe_redirect_params = { organization_id: current_organization.to_param }
      if @b_param.created_bike.present?
        flash[:success] = "#{@bike.created_bike.type} Created"
      else
        # we handle filtering & coercion in BParam, just create it with whatever here
        @b_param.update_attributes(permitted_create_params)
        @bike = BikeCreator.new(@b_param).create_bike
        if @bike.errors.any?
          @b_param.update_attributes(bike_errors: @bike.cleaned_error_messages)
          flash[:error] = @b_param.bike_errors.to_sentence
          iframe_redirect_params[:b_param_id_token] = @b_param.id_token
        else
          flash[:success] = "#{@bike.type} Created"
        end
      end
      redirect_back(fallback_location: new_iframe_organization_bikes_path(iframe_redirect_params))
    end

    private

    def find_or_new_b_param
      token = params[:b_param_token]
      token ||= params[:bike] && params[:bike][:b_param_id_token]
      b_param = BParam.find_or_new_from_token(token, user_id: current_user && current_user.id, organization_id: current_organization.id)
      b_param.origin = "organization_form"
      b_param
    end

    # TODO: make this less gross
    def permitted_create_params
      phash = params.as_json
      {
        origin: "organization_form",
        params: phash.merge("bike" => phash["bike"].merge(creation_organization_id: current_organization.id))
      }
    end

    def sortable_columns
      %w[id updated_at owner_email manufacturer_id frame_model stolen]
    end

    def organization_bikes
      current_organization.bikes.reorder("bikes.created_at desc")
    end

    def current_index_path
      organization_bikes_path(organization_id: current_organization.to_param)
    end

    def redirect_back_fallback_path
      if params[:id].present?
        bike_path(params[:id])
      else
        organization_bikes_path
      end
    end

    def search_organization_bikes
      @search_query_present = permitted_org_bike_search_params.except(:stolenness).values.reject(&:blank?).any?
      @interpreted_params = Bike.searchable_interpreted_params(permitted_org_bike_search_params, ip: forwarded_ip_address)
      org = current_organization || passive_organization
      if org.present?
        if params[:search_impoundedness] == "only_impounded"
          @impoundedness = "only_impounded"
          bikes = org.impounded_bikes
        else
          bikes = org.bikes
        end
        bikes = bikes.search(@interpreted_params)
        bikes = bikes.organized_email_search(params[:email]) if params[:email].present?
      else
        bikes = Bike.search(@interpreted_params)
      end
      @search_stickers = false
      if params[:search_stickers].present?
        @search_stickers = params[:search_stickers] == "none" ? "none" : "with"
        bikes = @search_stickers == "none" ? bikes.no_bike_sticker : bikes.bike_sticker
      else
        @search_stickers = false
      end
      @bikes = bikes.reorder("bikes.#{sort_column} #{sort_direction}").page(@page).per(@per_page)
      if @interpreted_params[:serial]
        @close_serials = organization_bikes.search_close_serials(@interpreted_params).limit(25)
      end
      @selected_query_items_options = Bike.selected_query_items_options(@interpreted_params)
    end
  end
end
