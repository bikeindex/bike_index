class Admin::UserAlertsController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @user_alerts = pagy(matching_user_alerts.order(sort_column => sort_direction), limit: @per_page, page: permitted_page)
    @render_kind_counts = InputNormalizer.boolean(params[:search_kind_counts])
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
      user_alerts = user_alerts.where(bike_id: @bike.id) if @bike.present?
    end
    @with_notification = InputNormalizer.boolean(params[:search_with_notification])
    user_alerts = user_alerts.with_notification if @with_notification
    if params[:organization_id].present? && current_organization.present?
      user_alerts = user_alerts.where(organization_id: current_organization.id)
    end
    @time_range_column = sort_column if %w[updated_at resolved_at dismissed_at].include?(sort_column)
    @time_range_column ||= "created_at"
    user_alerts.where(@time_range_column => @time_range)
  end

  def earliest_period_date
    Time.at(1624820303)
  end
end
