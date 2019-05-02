class Admin::FailedBikesController < Admin::BaseController
  layout "new_admin"

  def index
    page = params.fetch(:page, 1)
    per_page = params.fetch(:per_page, 25)

    @b_params_total_count = BParam.where("created_bike_id IS NOT NULL").count

    @b_params =
      BParam
        .where("created_bike_id IS NOT NULL")
        .order("created_at desc")
        .page(page)
        .per(per_page)
  end

  def show
    @b_param = BParam.find(params[:id])
  end
end
