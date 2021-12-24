class MyAccountsController < ApplicationController
  before_action :authenticate_user_for_my_accounts_controller, only: [:show, :choose_registration]

  def show
    page = params[:page] || 1
    @locks_active_tab = params[:active_tab] == "locks"
    @per_page = params[:per_page] || 20
    @bikes = current_user.bikes.reorder(updated_at: :desc).page(page).per(@per_page)
    @locks = current_user.locks
  end

  private

  def authenticate_user_for_my_accounts_controller
    authenticate_user(translation_key: :create_account, flash_type: :info)
  end
end
