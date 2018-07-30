class BikeCodesController < ApplicationController
  before_filter :find_bike_code

  def update

  end

  def scanned
    unless @bike_code.linkable_by?(current_user)
      flash[:error] = "You can't update that #{@bike_code.kind}. Please contact support@bikeindex.org if you think you should be able to"
      redirect_back(fallback_location: path_for_code)
      return
    end
    if @bike_code.bike.present?
      redirect_to bike_url(@bike_code.bike_id) and return
    elsif current_user.present?
      @bikes = current_user.bikes.reorder(created_at: :desc).limit(100)
    end
    @organization = @bike_code.organization
  end

  protected

  def find_bike_code
    unless current_user.present?
      flash[:error] = "You must be signed in to do that"
      redirect_back(fallback_location: path_for_code)
      return
    end
    @bike_code = BikeCode.lookup(params[:id], organization_id: params[:organization_id])
    raise ActionController::RoutingError.new("Not Found") unless @bike_code.present?
  end

  def path_for_code
    scanned_bike_path(params[:id], organization_id: params[:organization_id])
  end
end
