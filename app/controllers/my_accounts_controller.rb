class MyAccountsController < ApplicationController
  include UserEditable
  before_action :assign_edit_template, only: %i[edit update]
  before_action :authenticate_user_for_my_accounts_controller

  def show
    page = params[:page] || 1
    @locks_active_tab = params[:active_tab] == "locks"
    @per_page = params[:per_page] || 20
    @bikes = current_user.bikes.reorder(updated_at: :desc).page(page).per(@per_page)
    @locks = current_user.locks
  end

  def edit
    @user = current_user
    @page_errors = @user.errors
  end

  private

  def authenticate_user_for_my_accounts_controller
    authenticate_user(translation_key: :create_account, flash_type: :info)
  end
end
