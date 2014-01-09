class Admin::FailedBikesController < Admin::BaseController
  def index
    @b_params = BParam.where("created_bike_id IS NOT NULL").order("created_at desc")
  end

  def show
    @b_param = BParam.find(params[:id])
  end

end