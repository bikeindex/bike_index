class Admin::SuperuserAbilitiesController < Admin::BaseController
  include SortableTable

  before_action :find_superuser_ability, except: [:index]

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @superuser_abilities = pagy(searched_superuser_abilities.reorder("superuser_abilities.#{sort_column} #{sort_direction}")
      .includes(:user), limit: @per_page, page: permitted_page)
  end

  def edit
  end

  def update
    if @superuser_ability.update(permitted_parameters)
      flash[:success] = "Superuser Ability saved!"
      redirect_to edit_admin_superuser_ability_path(@superuser_ability)
    else
      render action: :edit
    end
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
    @deleted = InputNormalizer.boolean(params[:search_deleted])
    superuser_abilities = @deleted ? SuperuserAbility.unscoped : SuperuserAbility

    if SuperuserAbility.kinds.include?(params[:search_kind])
      @kind = params[:search_kind]
      superuser_abilities = superuser_abilities.public_send(@kind)
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

  def permitted_parameters
    su_options = params.permit(*SuperuserAbility::SU_OPTIONS)
      .select { |so| InputNormalizer.boolean(params[so]) }
    {su_options: su_options.keys}
  end
end
