class MyAccountsController < ApplicationController
  before_action :authenticate_user_for_my_accounts_controller, only: [:show, :choose_registration]

  def show
    page = params[:page] || 1
    @locks_active_tab = params[:active_tab] == "locks"
    @per_page = params[:per_page] || 20
    # If there are over 100 bikes created by the user, we'll have problems loading and sorting them
    if current_user.creation_states.limit(101).count > 100
      bikes = current_user.rough_approx_bikes.page(page).per(@per_page)
      @bikes = bikes.decorate
    else
      bikes = Kaminari.paginate_array(current_user.bikes).page(page).per(@per_page)
      @bikes = BikeDecorator.decorate_collection(bikes)
    end
    @locks = LockDecorator.decorate_collection(current_user.locks)
  end

  private

  def authenticate_user_for_my_accounts_controller
    authenticate_user(translation_key: :create_account, flash_type: :info)
  end
end
