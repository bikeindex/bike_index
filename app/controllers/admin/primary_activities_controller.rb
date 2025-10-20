class Admin::PrimaryActivitiesController < Admin::BaseController
  include SortableTable

  before_action :find_primary_activity, except: %i[index]

  def index
    @per_page = permitted_per_page(default: 60)
    @search_show_count = InputNormalizer.boolean(params[:search_show_count])
    @pagy, @collection = pagy(
      matching_primary_activities.includes(:primary_activity_family).reorder("primary_activities.#{sort_column} #{sort_direction}"),
      limit: @per_page,
      page: permitted_page
    )
  end

  def show
    redirect_to edit_admin_primary_activity_url(@primary_activity)
  end

  def edit
    @primary_activity_flavors = @primary_activity.primary_activity_flavors.by_priority.not_top_level
  end

  def update
    if @primary_activity.update(permitted_parameters)
      flash[:success] = "Saved!"
      redirect_to admin_primary_activities_url
    else
      render action: :edit
    end
  end

  helper_method :matching_primary_activities, :searchable_scopes

  protected

  def sortable_columns
    %w[priority created_at name family primary_activity_family_id]
  end

  def searchable_scopes
    %w[family flavor top_level]
  end

  def matching_primary_activities
    primary_activities = PrimaryActivity
    if params[:search_scope].present? && searchable_scopes.include?(params[:search_scope])
      @scope = params[:search_scope]
      primary_activities = primary_activities.send(@scope)
    end

    primary_activities
  end

  def find_primary_activity
    @primary_activity = PrimaryActivity.friendly_find(params[:id])
  end

  def permitted_parameters
    params.require(:primary_activity).permit(:priority)
  end
end
