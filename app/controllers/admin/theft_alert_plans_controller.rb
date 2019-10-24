class Admin::TheftAlertPlansController < Admin::BaseController
  def index
    @theft_alert_plans = TheftAlertPlan.order(:amount_cents)
  end

  def new
    @theft_alert_plan = TheftAlertPlan.new
  end

  def create
    @theft_alert_plan = TheftAlertPlan.new(theft_alert_plan_params)

    if @theft_alert_plan.save
      redirect_to(edit_admin_theft_alert_plan_path(@theft_alert_plan))
    else
      flash[:errors] = @theft_alert_plan.errors.full_messages
      render :new
    end
  end

  def edit
    @theft_alert_plan = TheftAlertPlan.find(params[:id])
  end

  def update
    @theft_alert_plan = TheftAlertPlan.find(params[:id])

    if @theft_alert_plan.update_attributes(theft_alert_plan_params)
      redirect_to(admin_theft_alert_plans_path)
    else
      flash[:errors] = @theft_alert_plan.errors.full_messages
      render :edit
    end
  end

  private

  def theft_alert_plan_params
    params
      .require(:theft_alert_plan)
      .permit(:name, :amount_cents, :views, :duration_days, :description, :active, :language)
  end
end
