class Admin::GraphsController < Admin::BaseController
  before_action :set_period
  before_action :set_variable_graph_kind

  def index
    @total_count = if @kind == "users"
      matching_users.count
    elsif @kind == "recoveries"
      matching_recoveries.where(recovered_at: @time_range).count
    elsif @kind == "bikes"
      matching_bikes.count
    end

  end

  def variable
    if @kind == "users"
      chart_data = helpers.time_range_counts(collection: User.where(created_at: @time_range))
    elsif @kind == "bikes"
      chart_data = bike_chart_data
    elsif @kind == "recoveries"
      chart_data = helpers.time_range_counts(collection: matching_recoveries)
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

  helper_method :bike_graph_kinds

  protected

  def set_variable_graph_kind
    @graph_kinds = %w[general users bikes recoveries]
    @kind = @graph_kinds.include?(params[:search_kind]) ? params[:search_kind] : @graph_kinds.first
  end

  def matching_users
    User.where(created_at: @time_range)
  end

  def matching_recoveries
    StolenRecord.unscoped.where(recovered_at: @time_range)
  end

  def matching_bikes
    bikes = Bike.unscoped.where(created_at: @time_range)
    bikes = bikes.where(deleted_at: nil) if !ParamsNormalizer.boolean(params[:search_deleted])
    bikes
  end

  def bike_graph_kinds
    %w[stolen origin pos]
  end

  def pos_search_kinds
    %w[lightspeed_pos ascend_pos any_pos no_pos]
  end

  def bike_chart_data
    bikes = matching_bikes
    @bike_graph_kind = bike_graph_kinds.include?(params[:bike_graph_kind]) ? params[:bike_graph_kind] : bike_graph_kinds.first
    if @bike_graph_kind == "stolen"
      [{
        name: "Registered",
        data: helpers.time_range_counts(collection: bikes)
      },
        {
          name: "Stolen bikes",
          data: helpers.time_range_counts(collection: StolenRecord.where(created_at: @time_range))
        }]
    elsif @bike_graph_kind == "origin"
      CreationState.origins.map do |origin|
        {
          name: origin.humanize,
          data: helpers.time_range_counts(collection: bikes.includes(:creation_states).where(creation_states: {origin: origin}))
        }
      end
    elsif @bike_graph_kind == "pos"
      pos_search_kinds.map do |pos_kind|
        {
          name: pos_kind.humanize,
          data: helpers.time_range_counts(collection: bikes.send(pos_kind))
        }
      end
    end
  end
end
