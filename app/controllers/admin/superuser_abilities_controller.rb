class Admin::SuperuserAbilitiesController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @superuser_abilities = searched_superuser_abilities.reorder("superuser_abilities.#{sort_column} #{sort_direction}")
      .includes(:user)
      .page(page).per(per_page)
  end

  helper_method :searched_superuser_abilities, :permitted_kinds

  private

  def sortable_columns
    %w[created_at updated_at kind user_id controller_name action_name]
  end

  def earliest_period_date
    Time.at(1650467457)
  end

  def permitted_kinds
    SuperuserAbility.kinds
  end

  def searched_superuser_abilities
    searched_superuser_abilities = SuperuserAbility
    if SuperuserAbility.kinds.include?(params[:search_kind])
      @kind = params[:search_kind]
      searched_superuser_abilities = searched_superuser_abilities.send(@kind)
    else
      @kind = "all"
    end
    @time_range_column = sort_column if %w[updated_at].include?(sort_column)
    @time_range_column ||= "created_at"
    searched_superuser_abilities.where(@time_range_column => @time_range)
  end
end
