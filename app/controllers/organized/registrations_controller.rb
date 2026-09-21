module Organized
  class RegistrationsController < Organized::BaseController
    include Binxtils::SortableTable

    SORTABLE_COLUMNS = %w[id updated_by_user_at owner_email mnfg_name frame_model cycle_type propulsion_type
      acknowledged_at]

    helper_method :chart_scope_paths

    skip_before_action :ensure_not_ambassador_organization!, only: [:multi_search, :multi_search_response]
    around_action :set_reading_role, only: :multi_search_response
    # new renders a component, which takes its content type from the request - and index
    # answers turbo_stream, so the format is one a link here could ask for
    before_action :force_html_response, only: :new

    def index
      return head(:not_acceptable) unless request.format.html? || request.format.turbo_stream?
      set_period
      @bike_sticker = BikeSticker.lookup_with_fallback(params[:bike_sticker], organization_id: current_organization.id) if params[:bike_sticker].present?

      if current_organization.enabled?("bike_search")
        @search_claimedness = "all"
        # Owner email and name only search the organization's own registrations
        @search_all_locked = params[:search_email].present?
        @search_all = !@search_all_locked && Binxtils::InputNormalizer.boolean(params[:search_all])
        @chart_scope = Pages::Org::Search::ChartCard::Component.permitted_scope(params[:chart_scope])
        # ui--collapse's, not the server's - normalized only so the form's hidden field
        # carries 1/0 rather than the blank a rider who never touched the card would send
        @chart_open = Binxtils::InputNormalizer.boolean(params[:chart_open]) ? "1" : "0"
        @result_view = Pages::Org::Search::Wrapper::Component.permitted_result_view(params[:search_result_view])
        @render_results = Binxtils::InputNormalizer.boolean(params[:search_no_js]) || turbo_request?
        @interpreted_params = BikeSearchable.searchable_interpreted_params(permitted_org_registration_search_params, ip: forwarded_ip_address)
        @per_page = permitted_per_page(default: 10)

        if create_export?
          search_organization_bikes
          create_export_and_redirect
        elsif chart_only?
          # The card counts the organization's own registrations, even while the search reaches past them
          @search_all = false
          search_organization_bikes
          render chart_card_component, layout: false
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

    # The /register flow's opening step, started here so the registration carries the
    # organized origin. Its submission, and every step after, continue on /register
    def new
      # Arriving here is the way back from the embed form, whatever sent them
      session.delete(:old_register_view)
      # "false" is owner_email_for's no-default sentinel - the member registering here
      # isn't the owner
      @b_param = BikeServices::Register.b_param_for(user: current_user, token_id: session[:register_b_param_token],
        status: BParam.status_hash_from_params(params)[:status], email: params[:email].presence || "false",
        origin: "register_flow_organized")
      BikeServices::Register.assign_organization(@b_param, current_organization)
      session[:register_b_param_token] = @b_param.id_token
      @page_title = I18n.t("meta_titles.register_step_1")
      # The unfinished_registration alert links into this flow, so it would sit on top of it
      @skip_general_alert = true
      # The form carries this registration's token, and a cached page would carry a stale one
      response.set_header("Cache-Control", "no-store")
      sequence = BikeServices::Register.registration_sequence(@b_param)
      steps = BikeServices::Register.steps(@b_param, sequence:)
      render Pages::Org::RegisterStep1::Component.new(b_param: @b_param, steps:,
        organization: current_organization, current_user:)
    end

    def multi_search
      @search_kind = normalized_search_kind
    end

    def multi_search_response
      @search_kind = normalized_search_kind
      @query = (sticker_search? ? params[:query] : params[:serial]).to_s.strip
      @chip_id = params[:chip_id].to_s.strip.presence
      return head(:bad_request) unless @query.present?

      @per_page = 10
      bikes = sticker_search? ? sticker_search_bikes : serial_search_bikes
      @pagy, @bikes = pagy(:countish, bikes.reorder("bikes.id desc"), limit: @per_page, page: permitted_page)
      @close_serials = @search_scope.search_close_serials(@interpreted_params).limit(25) if !sticker_search? && @bikes.none?
    end

    private

    def normalized_search_kind
      (params[:search_kind] == "stickers") ? "stickers" : "serials"
    end

    def sticker_search?
      @search_kind == "stickers"
    end

    def serial_search_bikes
      @search_all = Binxtils::InputNormalizer.boolean(params[:search_all])
      @interpreted_params = BikeSearchable.searchable_interpreted_params({serial: @query, stolenness: "all"}, ip: forwarded_ip_address)
      @search_scope = @search_all ? Bike : current_organization.bikes
      @search_scope.search(@interpreted_params)
    end

    # A blank normalized code makes sticker_code_search return `all`, so guard against it
    # surfacing every organization's bikes
    def sticker_search_bikes
      return Bike.none if BikeSticker.normalize_code(@query, leading_zeros: true).blank?

      bike_ids = BikeSticker.sticker_code_search(@query).claimed.select(:bike_id)
      Bike.where(id: bike_ids)
    end

    def sortable_columns
      SORTABLE_COLUMNS
    end

    # The frame asking, with no render_chart gate: the card always loads, and the scope links
    # put this URL in the address bar, where a reload has to be the whole page
    def chart_only?
      turbo_frame_request_id == Pages::Org::Search::ChartCard::Component::FRAME_ID.to_s
    end

    def chart_card_component
      Pages::Org::Search::ChartCard::Component.new(scope: @chart_scope, scope_paths: chart_scope_paths,
        chart: registrations_chart, stats: registrations_stats)
    end

    def chart_scope_paths
      @chart_scope_paths ||= Pages::Org::Search::ChartCard::Component::SCOPES.to_h do |scope|
        # The org is the path segment; left in the params it's a string key the route can't
        # read, so it would double up in the query these links advance the address bar to
        [scope.to_sym, organization_registrations_path(current_organization.to_param,
          helpers.sortable_search_params.except(:organization_id).merge(chart_scope: scope))]
      end
    end

    # `year` ignores the search, so the card still answers when the search has narrowed to
    # a handful of bikes
    def chart_scope_year?
      @chart_scope == "year"
    end

    def chart_bikes
      @chart_bikes ||= (chart_scope_year? ? organization_bikes : @searched_bikes).unscope(:order)
    end

    # Whole months, so the bars are comparable rather than the first and last being part ones
    def chart_time_range
      @chart_time_range ||= chart_scope_year? ? ((Time.current.beginning_of_month - 1.year)..Time.current) : @time_range
    end

    def registrations_stats
      @registrations_stats ||= cache_year_chart(:stats) do
        OrgServices::RegistrationCounts.for_range(chart_bikes, chart_time_range,
          compare: chart_scope_year? || @period != "all")
      end
    end

    def registrations_chart
      UI::Chart::Component.new(
        series: chart_band_counts.map { |key, data| {name: t("components.pages.org.search.chart_card.chart_#{key}"), data:} },
        time_range: chart_time_range,
        colors: Pages::Org::Search::ChartCard::Component::BANDS.values.map { it[:hex] },
        height: Pages::Org::Search::ChartCard::Component::CHART_HEIGHT,
        stacked: true
      )
    end

    # The bands partition the total: an e-vehicle reported stolen is counted once, as stolen
    def chart_band_counts
      @chart_band_counts ||= cache_year_chart(:bands) do
        in_range = chart_bikes.where(created_at: chart_time_range)
        not_stolen = in_range.where.not(status: "status_stolen")

        {registrations: chart_counts(not_stolen.where.not(propulsion_type: PropulsionType::MOTORIZED)),
         motorized: chart_counts(not_stolen.motorized),
         stolen: chart_counts(in_range.where(status: "status_stolen"))}
      end
    end

    # The year scope answers the organization rather than the search, so every member asks
    # for the same counts. Numbers only, so no locale in the key
    def cache_year_chart(key, &block)
      return yield unless chart_scope_year?

      Rails.cache.fetch(["org_registrations_chart", key, current_organization.id,
        Time.current.beginning_of_hour.to_i], expires_in: 1.hour, &block)
    end

    def chart_counts(bikes)
      UI::Chart::Component.time_range_counts(collection: bikes, time_range: chart_time_range, column: "bikes.created_at")
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
      set_search_filter_params
      bikes = (@search_all || org.blank?) ? Bike.search(@interpreted_params) : org.bikes.search(@interpreted_params)
      bikes = BikeServices::OrganizedSearch.email_and_name(bikes, params[:search_email])
      bikes = BikeServices::OrganizedSearch.notes(bikes, params[:search_notes], org) if params[:search_notes].present? && org.present?
      bikes = BikeServices::OrganizedSearch.stickers(bikes, @search_stickers)
      bikes = BikeServices::OrganizedSearch.address(bikes, @search_address)
      bikes = BikeServices::OrganizedSearch.status(bikes, search_status)
      bikes = unregisteredness_scoped(bikes)
      if params[:search_model_audit_id].present?
        @model_audit = ModelAudit.find_by_id(params[:search_model_audit_id])
        bikes = bikes.where(model_audit_id: params[:search_model_audit_id])
      end
      # The chart card counts an earlier window too, so it needs the search without a period
      @searched_bikes = bikes
      @available_bikes = @searched_bikes.where(created_at: @time_range)
      return if chart_only?

      @pagy, @bikes = pagy(:countish, @available_bikes.reorder(search_order(org)),
        limit: @per_page, page: permitted_page, **search_all_count)
    end

    # Searching past the organization reaches most of the index, so it counts - and pages -
    # only as far as the card says it counted
    def search_all_count
      return {} unless @search_all

      {count: @available_bikes.limit(BikeServices::OrganizedSearch::SEARCH_ALL_COUNT_LIMIT).count}
    end

    def search_order(organization)
      return "bikes.#{sort_column} #{sort_direction}" if sort_column != "acknowledged_at"

      RegistrationSequenceAcknowledgment.bikes_order(organization:, direction: sort_direction)
    end

    # The shell render and the search both read the filters normalized here
    def set_search_filter_params
      @search_stickers = if params[:search_stickers].present?
        (params[:search_stickers] == "none") ? "none" : "with"
      else
        false
      end
      @search_address = %w[none with with_street without_street].include?(params[:search_address]) ? params[:search_address] : false
      @search_unregisteredness = permitted_filter(:search_unregisteredness)
      search_status
    end

    # Off the chips' own table, so a value can't be added to one side only
    def permitted_filter(param)
      values = ComponentStructs::OrgSearchSettings::FILTER_GROUPS.fetch(param)[:values]

      values.key?(params[param].to_s.to_sym) ? params[param] : false
    end

    # A question about the bike's own status, not the notices on it - and the same column
    # search_status filters, so setting both to named statuses matches nothing
    def unregisteredness_scoped(bikes)
      case @search_unregisteredness
      when "only_unregistered" then bikes.unregistered_parking_notification
      when "only_registered" then bikes.not_unregistered_parking_notification
      else bikes
      end
    end

    def search_status
      return @search_status if defined?(@search_status)

      valid_statuses = ComponentStructs::OrgSearchSettings.filter_values(:search_status, current_organization)
      @search_status = valid_statuses.include?(params[:search_status]) ? params[:search_status] : default_status
    end

    # An impound-enabled organization's registrations leave impounded bikes out unless asked
    def default_status
      current_organization.enabled?("impound_bikes") ? "not_impounded" : "all"
    end

    # An export reaches every matched bike, so it's refused once the search has widened
    # past the organization's own registrations
    def create_export?
      current_organization.enabled?("csv_exports") && !@search_all &&
        Binxtils::InputNormalizer.boolean(params[:create_export])
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
        flash[:notice] = "Directly creating export - can't configure with over 500 bikes"
        export = Export.create(create_export_params)
        OrganizationExportJob.perform_async(export.id)
        redirect_to organization_export_path(export, organization_id: current_organization.id)
      else
        if bikes_count == 0
          flash[:error] = "There are no matching bikes!"
        elsif bikes_count > 200
          flash[:notice] = "Warning: Exporting from search with this many matching bikes may not work correctly"
        end
        redirect_to new_organization_export_path(new_export_params_custom_bike_ids)
      end
    end

    def no_org_search_params?
      return false if params[:search_stickers].present? && params[:search_stickers] != "all"

      params.slice(:search_address, :search_email, :search_model_audit_id, :search_notes, :search_status,
        :search_unregisteredness).values.reject(&:blank?).none?
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
      @search_claimedness = %w[transferred initial].include?(params[:search_claimedness]) ? params[:search_claimedness] : "all"
      bikes = if @search_claimedness == "initial"
        bikes.joins(:ownerships).where(ownerships: {current: true, previous_ownership_id: nil})
      elsif @search_claimedness == "transferred"
        bikes.joins(:ownerships).where.not(ownerships: {previous_ownership_id: nil})
      else
        bikes
      end
      bikes.where(created_at: @time_range)
    end
  end
end
