class MyAccountsController < ApplicationController
  before_action :authenticate_user_for_my_accounts_controller, only: [:show, :choose_registration]

  def show
    page = params[:page] || 1
    @locks_active_tab = params[:active_tab] == "locks"
    @per_page = params[:per_page] || 20
    # If there are over 100 bikes created by the user, we'll have problems loading and sorting them
    @bikes = if current_user.ownerships.current.limit(101).count > 100
      current_user.rough_approx_bikes.reorder(updated_at: :desc).page(page).per(@per_page)
    else
      Kaminari.paginate_array(current_user.bikes).page(page).per(@per_page)
    end
    @locks = current_user.locks
  end

  private

  def authenticate_user_for_my_accounts_controller
    authenticate_user(translation_key: :create_account, flash_type: :info)
  end
end
