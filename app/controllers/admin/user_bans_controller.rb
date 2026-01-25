class Admin::UserBansController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @collection = pagy(:countish,
      matching_user_bans.includes(:user, :creator).reorder("user_bans.#{sort_column} #{sort_direction}"),
      limit: @per_page,
      page: permitted_page)
  end

  helper_method :matching_user_bans, :viewing_deleted?

  protected

  def sortable_columns
    %w[created_at reason user_id creator_id]
  end

  def viewing_deleted?
    @viewing_deleted ||= params[:deleted].present?
  end

  def matching_user_bans
    user_bans = viewing_deleted? ? UserBan.only_deleted : UserBan
    user_bans.where(created_at: @time_range)
  end
end
