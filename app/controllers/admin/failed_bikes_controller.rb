class Admin::FailedBikesController < Admin::BaseController
  def index
    @bikeParams = BParam.where("created_bike_id IS NOT NULL").order("created_at desc")
  end

  def show
    @bikeParam = BParam.find(params[:id])
  end

end