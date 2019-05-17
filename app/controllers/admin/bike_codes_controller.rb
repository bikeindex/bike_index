class Admin::BikeCodesController < Admin::BaseController
  include SortableTable
  layout "new_admin"

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    @bike_codes = matching_bike_codes.reorder("bike_codes.#{sort_column} #{sort_direction}")
                                     .includes(:bike, :organization).page(page).per(per_page)
  end

  helper_method :matching_bike_codes

  private

  def sortable_columns
    %w[created_at code organization_id bike_code_batch_id]
  end

  def matching_bike_codes
    bike_codes = BikeCode.all
    if params[:organization_id].present?
      bike_codes = bike_codes.where(organization_id: current_organization.id)
    end
    if params[:search_bike_code_batch_id].present?
      @bike_code_batch = BikeCodeBatch.find(params[:search_bike_code_batch_id])
      bike_codes = bike_codes.where(bike_code_batch_id: @bike_code_batch.id)
    end
    if params[:search_query].present?
      bike_codes = bike_codes.admin_text_search(params[:search_query])
    end
    bike_codes
  end
end
