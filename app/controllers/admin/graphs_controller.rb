module Admin
  class GraphsController < Admin::BaseController
    before_action :set_period
    before_action :set_variable_graph_kind
    around_action :set_reading_role

    def index
      @total_count = if @kind == "users"
        matching_users.count
      elsif @kind == "recoveries"
        matching_recoveries.where(recovered_at: @time_range).count
      elsif @kind == "bikes"
        matching_bikes.count
      end
      @page_title = "#{@kind.humanize} graphs"
    end

    # Always an array of named series, even for one: chartkick's single-series format
    # paints every bar a separate color out of the palette UI::Chart::Component passes
    def variable
      chart_data = case @kind
      when "users" then [{name: "Users", data: helpers.time_range_counts(collection: matching_users)}]
      when "bikes" then bike_chart_data
      when "recoveries" then [{name: "Recoveries", data: helpers.time_range_counts(collection: matching_recoveries)}]
      end
      if chart_data.present?
        render json: chart_data.chart_json
      else
        render json: {error: "unable to parse chart"}
      end
    end

    def bikes_table
      render Pages::Admin::Graphs::BikesTable::Component.new(kind: params[:table_kind], bikes: matching_bikes,
        time_range: @time_range, sortable_params: helpers.sortable_search_params.to_h.symbolize_keys), layout: false
    end

    def tables
      @kind = ""
      @location_radius = params[:location_radius].presence&.to_i || 100
      @bounding_box = GeocodeHelper.bounding_box(params[:location], @location_radius) if params[:location].present?
    end

    helper_method :matching_bikes, :default_period

    protected

    def set_variable_graph_kind
      # NOTE: pos_integrations redirects you to the OrganizationStatusesController
      @graph_kinds = %w[general users bikes recoveries pos_integrations]
      @kind = @graph_kinds.include?(params[:search_kind]) ? params[:search_kind] : @graph_kinds.first
    end

    def matching_users
      User.where(created_at: @time_range)
    end

    def matching_recoveries
      StolenRecord.recovered.where(recovered_at: @time_range)
    end

    def matching_bikes
      return @matching_bikes if defined?(@matching_bikes)

      bikes = Bike.unscoped.where(created_at: @time_range)
      if params[:search_manufacturer].present?
        @manufacturer = Manufacturer.friendly_find(params[:search_manufacturer])
        bikes = if @manufacturer.present?
          bikes.where(manufacturer_id: @manufacturer&.id)
        else
          bikes.where(mnfg_name: params[:search_manufacturer])
        end
      end
      @matching_bikes = admin_search_bike_statuses(bikes)
    end

    def default_period
      "year"
    end

    def bike_graph_kinds
      %w[stolen origin ios_version pos ignored]
    end

    # {group => {time => count}}, grouped by both so it's one query rather than one per
    # group. Distinct: a bike has an ownership per transfer
    def grouped_time_range_counts(collection)
      helpers.time_range_counts(column: "bikes.created_at", collection: collection.distinct)
        .each_with_object({}) { |((group, at), count), h| (h[group] ||= {})[at] = count }
    end

    # Groupdate's range only fills the origins it found rows for, so the rest take the empty series
    def origin_chart_series(bikes)
      series = grouped_time_range_counts(bikes.joins(:ownerships).group("ownerships.origin"))
      empty = helpers.empty_time_range_counts
      Ownership.origins.map do |origin|
        {name: origin.humanize, color: Pages::Admin::Graphs::BikesTable::Component::ORIGIN_COLORS[origin], data: empty.merge(series[origin] || {})}
      end
    end

    # Ordered like the component's table, so the chart's legend matches it
    def ios_version_chart_series
      grouped_time_range_counts(Pages::Admin::Graphs::BikesTable::Component.ios_version_bikes(matching_bikes))
        .sort_by { |version, data| [-data.values.sum, version] }
        .map { |version, data| {name: "iOS #{version}", data:} }
    end

    def bike_chart_data
      bikes = matching_bikes
      bike_graph_kind = bike_graph_kinds.include?(params[:bike_graph_kind]) ? params[:bike_graph_kind] : bike_graph_kinds.first
      if bike_graph_kind == "stolen"
        [
          {
            name: "Registered bikes",
            data: helpers.time_range_counts(collection: bikes)
          },
          {
            name: "Stolen records",
            data: helpers.time_range_counts(collection: StolenRecord.unscoped.joins(:bike).merge(bikes), column: "stolen_records.created_at")
          }
        ]
      elsif bike_graph_kind == "origin"
        origin_chart_series(bikes)
      elsif bike_graph_kind == "ios_version"
        ios_version_chart_series
      elsif bike_graph_kind == "pos"
        Pages::Admin::Graphs::BikesTable::Component::POS_SEARCH_KINDS.map do |pos_kind|
          {
            name: pos_kind.humanize,
            data: helpers.time_range_counts(collection: bikes.send(pos_kind))
          }
        end
      elsif bike_graph_kind == "ignored"
        [
          {
            name: "Spam",
            data: helpers.time_range_counts(collection: bikes.spam)
          },
          {
            name: "Deleted",
            data: helpers.time_range_counts(collection: bikes.deleted)
          },
          {
            name: "Test",
            data: helpers.time_range_counts(collection: bikes.example)
          }
        ]
      end
    end
  end
end
