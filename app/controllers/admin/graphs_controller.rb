class Admin::GraphsController < Admin::BaseController
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

  def variable
    chart_data = if @kind == "users"
      helpers.time_range_counts(collection: User.where(created_at: @time_range))
    elsif @kind == "bikes"
      bike_chart_data
    elsif @kind == "recoveries"
      helpers.time_range_counts(collection: matching_recoveries)
    end
    if chart_data.present?
      render json: chart_data.chart_json
    else
      render json: {error: "unable to parse chart"}
    end
  end

  def tables
    @kind = ""
  end

  helper_method :shown_bike_graph_kinds, :matching_bikes, :pos_search_kinds, :default_period

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
    %w[stolen origin pos ignored]
  end

  def shown_bike_graph_kinds
    bike_graph_kinds - ["ignored"]
  end

  def pos_search_kinds
    %w[lightspeed_pos ascend_pos does_not_need_pos no_pos]
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
      Ownership.origins.map do |origin|
        {
          name: origin.humanize,
          data: helpers.time_range_counts(collection: bikes.includes(:ownerships).where(ownerships: {origin: origin}))
        }
      end
    elsif bike_graph_kind == "pos"
      pos_search_kinds.map do |pos_kind|
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
