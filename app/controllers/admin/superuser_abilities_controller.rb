class Admin::SuperuserAbilitiesController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: [:index]
  before_action :find_superuser_ability, except: [:index]

  def index
    page = params[:page] || 1
    @per_page = params[:per_page] || 50
    @superuser_abilities = searched_superuser_abilities.reorder("superuser_abilities.#{sort_column} #{sort_direction}")
      .includes(:user)
      .page(page).per(@per_page)
  end

  def edit
  end

  def update
  end

  helper_method :searched_superuser_abilities, :permitted_kinds

  private

  def find_superuser_ability
    @superuser_ability = SuperuserAbility.find(params[:id])
  end

  def sortable_columns
    %w[created_at updated_at kind user_id controller_name action_name]
  end

  def earliest_period_date
    Date.parse("2013-1-1").beginning_of_day # First user created 2013-1-11
  end

  def permitted_kinds
    SuperuserAbility.kinds
  end

  def searched_superuser_abilities
    @deleted = ParamsNormalizer.boolean(params[:search_deleted])
    superuser_abilities = @deleted ? SuperuserAbility.unscoped : SuperuserAbility

    if SuperuserAbility.kinds.include?(params[:search_kind])
      @kind = params[:search_kind]
      superuser_abilities = superuser_abilities.send(@kind)
    else
      @kind = "all"
    end
    if params[:user_id].present?
      superuser_abilities = superuser_abilities.where(user_id: params[:user_id])
    end

    @time_range_column = sort_column if %w[updated_at].include?(sort_column)
    @time_range_column ||= "created_at"
    superuser_abilities.where(@time_range_column => @time_range)
  end
end
