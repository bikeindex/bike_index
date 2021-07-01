class Admin::UserAlertsController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @user_alerts = matching_user_alerts.order(sort_column => sort_direction)
      .page(page).per(per_page)
  end

  helper_method :matching_user_alerts

  private

  def sortable_columns
    %w[created_at updated_at resolved_at dismissed_at kind user_id]
  end

  def matching_user_alerts
    user_alerts = UserAlert
    if UserAlert.kinds.include?(params[:search_kind])
      @kind = params[:search_kind]
      user_alerts = user_alerts.where(kind: @kind)
    else
      @kind = "all"
    end
    if %w[active inactive dismissed resolved].include?(params[:search_activeness])
      @activeness = params[:search_activeness]
      user_alerts = user_alerts.send(@activeness)
    else
      @activeness = "all"
    end
    if params[:user_id].present?
      @user = User.unscoped.friendly_find(params[:user_id])
      user_alerts = user_alerts.where(user_id: @user.id) if @user.present?
    end
    if params[:search_bike_id].present?
      @bike = Bike.unscoped.find(params[:search_bike_id])
      user_alerts = user_alerts.where(search_bike_id: @bike.id) if @bike.present?
    end
    if params[:organization_id].present? && current_organization.present?
      user_alerts = user_alerts.where(organization_id: current_organization.id)
    end
    # I don't know why this isn't working - see also notifications - ignoring and forcing created_at
    # @time_range_column = sort_column if %w[updated_at resolved_at dismissed_at].include?(sort_column)
    @time_range_column ||= "created_at"
    # user_alerts.where(@time_range_colum => @time_range).order(:id)
    user_alerts.where(created_at: @time_range)
  end

  def earliest_period_date
    Time.at(1624820303)
  end
end
