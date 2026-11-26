module Organized
  class RecoveriesController < Organized::BaseController
    before_action :force_html_response
    before_action :ensure_recoveries_enabled!

    def index
      set_period
      @distance = Pages::Org::Recoveries::Index::Component.permitted_distance(params[:search_distance])
      # Without coordinates there's nothing to measure a distance from
      @only_organization = !current_organization.search_coordinates_set? ||
        Binxtils::InputNormalizer.boolean(params[:search_only_organization])
      @pagy, recoveries = pagy(:countish, matching_recoveries.reorder(recovered_at: :desc)
        .includes(:bike, :region_record, :country),
        limit: 25, page: permitted_page)

      render Pages::Org::Recoveries::Index::Component.new(organization: current_organization,
        recoveries:, pagy: @pagy, distance: @distance,
        only_organization: @only_organization, organized_bike_ids: organized_bike_ids(recoveries),
        result_view: params[:search_result_view], period: @period, start_time: @start_time,
        end_time: @end_time, sortable_search_params: helpers.sortable_search_params, params:)
    end

    private

    # A recovery near the organization can predate it, so all time reaches past its creation
    def earliest_period_date = default_earliest_time

    def ensure_recoveries_enabled!
      return if current_organization.enabled?("show_recoveries")

      redirect_to organization_registrations_path(organization_id: current_organization.to_param)
    end

    # The bike's default scope leaves out hidden and deleted bikes, which the rows can't render
    def matching_recoveries
      recoveries = if @only_organization
        current_organization.recovered_records
      else
        nearby_recoveries
      end
      recoveries.where(recovered_at: @time_range, bike_id: Bike.unscoped.current.select(:id))
    end

    # The box narrows by index; its corners reach past the radius, so the distance trims them
    def nearby_recoveries
      coordinates = current_organization.search_coordinates
      distance_sql = Geocoder::Sql.full_distance(*coordinates, "stolen_records.latitude",
        "stolen_records.longitude", units: :mi)

      StolenRecord.recovered.within_bounding_box(GeocodeHelper.bounding_box(coordinates, @distance))
        .where("#{distance_sql} <= ?", @distance)
    end

    def organized_bike_ids(recoveries)
      current_organization.bike_organizations_ever_registered
        .where(bike_id: recoveries.map(&:bike_id)).pluck(:bike_id)
    end
  end
end
