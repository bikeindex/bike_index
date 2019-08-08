class Admin::FailedBikesController < Admin::BaseController
  def index
    page = params.fetch(:page, 1)
    per_page = params.fetch(:per_page, 25)

    @b_params =
      BParam
        .includes(:creator)
        .where("created_bike_id IS NOT NULL")
        .order("created_at desc")
        .page(page)
        .per(per_page)
  end

  def show
    @b_param = BParam.find(params[:id])
  end
end
