class Admin::PromotedAlertPlansController < Admin::BaseController
  def index
    @promoted_alert_plans = PromotedAlertPlan.order(:amount_cents)
  end

  def new
    @promoted_alert_plan = PromotedAlertPlan.new
  end

  def create
    @promoted_alert_plan = PromotedAlertPlan.new(promoted_alert_plan_params)

    if @promoted_alert_plan.save
      redirect_to(edit_admin_promoted_alert_plan_path(@promoted_alert_plan))
    else
      flash[:errors] = @promoted_alert_plan.errors.full_messages
      render :new
    end
  end

  def edit
    @promoted_alert_plan = PromotedAlertPlan.find(params[:id])
  end

  def update
    @promoted_alert_plan = PromotedAlertPlan.find(params[:id])

    if @promoted_alert_plan.update(promoted_alert_plan_params)
      redirect_to(admin_promoted_alert_plans_path)
    else
      flash[:errors] = @promoted_alert_plan.errors.full_messages
      render :edit
    end
  end

  private

  def promoted_alert_plan_params
    params
      .require(:promoted_alert_plan)
      .permit(:name, :amount_cents, :views, :duration_days, :description, :active, :language,
        :currency_enum, :amount_cents_facebook, :ad_radius_miles)
  end
end
