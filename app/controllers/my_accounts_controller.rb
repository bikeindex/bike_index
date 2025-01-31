class MyAccountsController < ApplicationController
  include Sessionable
  before_action :assign_edit_template, only: %i[edit update destroy]
  before_action :authenticate_user_for_my_accounts_controller
  around_action :set_reading_role, only: %i[show]

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
    @page_title = @edit_templates[@edit_template]
  end

  def update
    @user = current_user
    if params.dig(:user, :password).present?
      unless @user.authenticate(params.dig(:user, :current_password))
        @user.errors.add(:base, translation(:current_password_doesnt_match))
      end
    end
    unless @user.errors.any?
      successfully_updated = update_hot_sheet_notifications || update_user_registration_organizations
      @user.address_set_manually = true if params&.dig(:user, :street).present?
      if params[:user].present? && @user.update(permitted_parameters)
        successfully_updated = true
        if params.dig(:user, :password).present?
          update_user_authentication_for_new_password
          default_session_set(@user)
        end
      end
      if successfully_updated
        flash[:success] ||= translation(:successfully_updated)
        # NOTE: switched to edit_template in #2040 (from page), because page is used for pagination
        redirect_back(fallback_location: edit_my_account_url(edit_template: @edit_template)) && return
      end
    end
    @page_errors = @user.errors.full_messages
    render action: :edit
  end

  def destroy
    if current_user.deletable?
      UserDeleteWorker.new.perform(current_user.id, user: current_user)
      remove_session
      redirect_to goodbye_url, notice: "Account deleted!"
    else
      error_reason = if current_user.superuser?
        "Super User's can't delete their account."
      else
        "Organization admins cannot delete their accounts."
      end
      flash[:error] = [error_reason, "Email support@bikeindex.org for help"].join(" ")
      redirect_back(fallback_location: edit_my_account_url(edit_template: @edit_template))
    end
  end

  private

  def authenticate_user_for_my_accounts_controller
    authenticate_user(translation_key: :create_account, flash_type: :info)
  end

  def edit_templates
    @edit_templates ||= {
      root: translation(:user_settings, scope: [:controllers, :my_accounts, :edit]),
      password: translation(:password, scope: [:controllers, :my_accounts, :edit]),
      sharing: translation(:sharing, scope: [:controllers, :my_accounts, :edit]),
      delete_account: translation(:delete_account, scope: [:controllers, :my_accounts, :edit])
    }.merge(registration_organization_template).as_json
  end

  def registration_organization_template
    return {} unless current_user&.user_registration_organizations.present?
    {registration_organizations: translation(:registration_organizations, scope: [:controllers, :my_accounts, :edit])}
  end

  def assign_edit_template
    @edit_template = edit_templates[params[:edit_template]].present? ? params[:edit_template] : edit_templates.keys.first
  end

  def update_hot_sheet_notifications
    return false unless params[:hot_sheet_organization_ids].present?
    params[:hot_sheet_organization_ids].split(",").each do |org_id|
      notify = params.dig(:hot_sheet_notifications, org_id).present?
      membership = @user.memberships.where(organization_id: org_id).first
      next unless membership.present?
      membership.update(hot_sheet_notification: notify ? "notification_daily" : "notification_never")
      flash[:success] ||= "Notification setting updated"
    end
    true
  end

  def update_user_registration_organizations
    return false unless params.key?(:user_registration_organization_all_bikes)
    uro_all_bikes = (params[:user_registration_organization_all_bikes] || []).reject(&:blank?).map(&:to_i)
    uro_can_edit_claimed = (params[:user_registration_organization_can_edit_claimed] || []).reject(&:blank?).map(&:to_i)
    new_registration_info = calculated_new_registration_info
    @user.user_registration_organizations.each do |user_registration_organization|
      user_registration_organization.update(skip_after_user_change_worker: true,
        all_bikes: uro_all_bikes.include?(user_registration_organization.id),
        can_edit_claimed: uro_can_edit_claimed.include?(user_registration_organization.id),
        registration_info: user_registration_organization.registration_info.merge(new_registration_info))
    end
    @user.update(updated_at: Time.current) # Bump user to enqueue AfterUserChangeWorker
    @user
  end

  def calculated_new_registration_info
    # Select the matching key value pairs, and rename them
    new_info = params.as_json.map do |k, v|
      next unless k.match?(/reg_field-/)
      [k.gsub("reg_field-", ""), v]
    end.compact.to_h
    # merge in existing registration_info
    UserRegistrationOrganization.universal_registration_info_for(current_user)
      .merge(new_info)
  end

  def permitted_parameters
    pparams = params.require(:user)
      .permit(:name, :username, :notification_newsletters, :notification_unstolen, :no_non_theft_notification,
        :additional_emails, :title, :description, :phone, :street, :city, :zipcode, :country_id,
        :state_id, :avatar, :avatar_cache, :twitter, :show_twitter, :instagram, :show_instagram,
        :show_website, :show_bikes, :show_phone, :my_bikes_link_target, :time_single_format,
        :my_bikes_link_title, :password, :password_confirmation, :preferred_language,
        user_registration_organization_attributes: [:all_bikes, :can_edit_claimed])
    if pparams.key?("username")
      pparams.delete("username") unless pparams["username"].present?
    end
    pparams
  end
end
