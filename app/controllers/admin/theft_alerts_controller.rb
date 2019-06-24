class Admin::TheftAlertsController < Admin::BaseController
  layout "new_admin"

  before_action :find_theft_alert, only: [:edit, :update]

  # TODO: Add sorting and filtering
  def index
    @theft_alerts =
      TheftAlert
        .includes(:theft_alert_plan)
        .creation_ordered_desc
        .page(params.fetch(:page, 1))
        .per(params.fetch(:per_page, 25))
  end

  def edit; end

  def update
    if @theft_alert.update(theft_alert_params)
      flash[:success] = "Success!"
      redirect_to admin_theft_alerts_path
    else
      flash[:error] = @theft_alert.errors.to_a
      render :edit
    end
  end

  private

  def find_theft_alert
    @theft_alert = TheftAlert.find(params[:id])
  end

  def theft_alert_params
    params
      .require(:theft_alert)
      .permit(:status, :facebook_post_url, :notes, :begin_at, :end_at)
  end
end
