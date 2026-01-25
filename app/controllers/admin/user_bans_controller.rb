class Admin::UserBansController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @collection = pagy(:countish,
      matching_user_bans.includes(:user, :creator).reorder("user_bans.#{sort_column} #{sort_direction}"),
      limit: @per_page,
      page: permitted_page)
  end

  helper_method :matching_user_bans

  protected

  def sortable_columns
    %w[created_at reason user_id creator_id]
  end

  def earliest_period_date
    Time.at(1665173442) # 2022-10-01 00:00 - user ban model added
  end

  def viewing_deleted?
  end

  def matching_user_bans
    @viewing_deleted = Binxtils::InputNormalizer.boolean(params[:search_deleted])
    user_bans = @viewing_deleted ? UserBan.only_deleted : UserBan

    if params[:user_id].present?
      user_bans = user_bans.where(creator_id: user_subject&.id || params[:user_id])
    end

    user_bans.where(created_at: @time_range)
  end
end
