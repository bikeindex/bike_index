class UsersController < ApplicationController
  include Sessionable
  before_action :authenticate_user, only: %i[edit update]
  before_action :skip_if_signed_in, only: %i[new globalid]
  before_action :assign_edit_template, only: %i[edit update]
  before_action :find_user_from_password_reset_token!, only: %i[update_password_form_with_reset_token update_password_with_reset_token]

  def new
    @user ||= User.new(email: params[:email])
    render_partner_or_default_signin_layout
  end

  def create
    @user = User.new(permitted_parameters)
    # Set the user's preferred locale if they have a locale we recognize
    if requested_locale != I18n.default_locale
      @user.preferred_language = requested_locale
    end
    if @user.save
      sign_in_and_redirect(@user)
    else
      @page_errors = @user.errors
      render_partner_or_default_signin_layout(render_action: :new)
    end
  end

  def please_confirm_email
    redirect_to(user_root_url) && return if current_user.present?
    if params[:require_sign_in].present?
      redirect_to(new_session_path) && return unless unconfirmed_current_user.present?
    end
    @user = unconfirmed_current_user
    render layout: sign_in_partner == "bikehub" ? "application_bikehub" : "application"
  end

  def resend_confirmation_email
    user_subject = unconfirmed_current_user
    user_subject ||= User.unconfirmed.fuzzy_unconfirmed_primary_email_find(params[:email])
    if user_subject.present?
      EmailConfirmationWorker.new.perform(user_subject.id)
      flash[:success] = translation(:resending_email)
    else
      flash[:error] = translation(:please_sign_in)
    end
    redirect_to please_confirm_email_users_path
  end

  def confirm
    @user = User.find(params[:id])
    if @user.confirmed?
      flash[:success] = translation(:already_confirmed)
      # If signed in, redirect to partner if it should
      if current_user.present? && sign_in_partner.present?
        session.delete(:partner) # Only removing once signed in, PR#1435
        redirect_to(bikehub_url("account?reauthenticate_bike_index=true")) && return # Only partner rn is bikehub, hardcode it
      else
        render_partner_or_default_signin_layout(redirect_path: new_session_path)
      end
    elsif @user.confirm(params[:code])
      sign_in_and_redirect(@user)
    else
      render :confirm_error_bad_token
    end
  rescue ActiveRecord::RecordNotFound
    render :confirm_error_404
  end

  def request_password_reset_form
  end

  def send_password_reset_email
    @user = User.fuzzy_confirmed_or_unconfirmed_email_find(params[:email])
    if @user.present?
      flash[:error] = translation(:reset_just_sent_wait_a_sec) unless @user.send_password_reset_email
    else
      flash[:error] = translation(:email_not_found)
      redirect_to request_password_reset_form_users_path
    end
  end

  def update_password_form_with_reset_token
  end

  def update_password_with_reset_token
    if @user.present? && @user.update_attributes(permitted_password_reset_parameters)
      flash[:success] = translation(:password_reset_successfully)
      # They got the password reset email, which counts as confirming their email
      @user.confirm(@user.confirmation_token) if @user.unconfirmed?
      update_user_authentication_for_new_password
      sign_in_and_redirect(@user)
    elsif @user.present?
      @page_errors = @user.errors
      render :update_password_form_with_reset_token
    end
  end

  def show
    user = User.find_by_username(params[:id])
    unless user
      raise ActionController::RoutingError.new("Not Found")
    end
    @owner = user
    @user = user
    unless user == current_user || @user.show_bikes
      redirect_to(my_account_url, notice: translation(:user_not_sharing)) && return
    end
    @page = params[:page] || 1
    @per_page = params[:per_page] || 9
    bikes = user.bikes(true).page(@page).per(@per_page)
    @bikes = BikeDecorator.decorate_collection(bikes)
  end

  def edit
    @user = current_user
    @page_errors = @user.errors
  end

  def update
    @user = current_user
    if params.dig(:user, :password).present?
      unless @user.authenticate(params.dig(:user, :current_password))
        @user.errors.add(:base, translation(:current_password_doesnt_match))
      end
    end
    unless @user.errors.any?
      successfully_updated = update_hot_sheet_notifications
      if params[:user].present? && @user.update_attributes(permitted_update_parameters)
        successfully_updated = true
        if params.dig(:user, :terms_of_service).present?
          if ParamsNormalizer.boolean(params.dig(:user, :terms_of_service))
            @user.terms_of_service = true
            @user.save
            flash[:success] = translation(:you_can_use_bike_index)
            redirect_to(my_account_url) && return
          else
            flash[:notice] = translation(:accept_tos)
            redirect_to(accept_terms_url) && return
          end
        elsif params.dig(:user, :vendor_terms_of_service).present?
          if ParamsNormalizer.boolean(params[:user][:vendor_terms_of_service])
            @user.update_attributes(accepted_vendor_terms_of_service: true)
            flash[:success] = if @user.memberships.any?
              translation(:you_can_use_bike_index_as_org, org_name: @user.memberships.first.organization.name)
            else
              translation(:thanks_for_accepting_tos)
            end
            redirect_to(user_root_url) && return
          else
            redirect_to(accept_vendor_terms_path, notice: translation(:accept_tos_to_use_as_org)) && return
          end
        end
        if params.dig(:user, :password).present?
          update_user_authentication_for_new_password
          default_session_set(@user)
        end
      end
      if successfully_updated
        flash[:success] ||= translation(:successfully_updated)
        redirect_back(fallback_location: edit_my_account_url(page: params[:page])) && return
      end
    end
    @page_errors = @user.errors.full_messages
    render action: :edit
  end

  def accept_terms
    if current_user.present?
      @user = current_user
    else
      redirect_to terms_url
    end
  end

  def accept_vendor_terms
    if current_user.present?
      @user = current_user
    else
      redirect_to vendor_terms_url
    end
  end

  def unsubscribe
    user = User.find_by_username(params[:id])
    user.update_attribute :notification_newsletters, false if user.present?
    flash[:success] = translation(:successfully_unsubscribed)
    redirect_to(user_root_url) && return
  end

  private

  def permitted_parameters
    params.require(:user)
      .permit(:name, :username, :email, :notification_newsletters, :notification_unstolen, :terms_of_service,
        :additional_emails, :title, :description, :phone, :street, :city, :zipcode, :country_id,
        :state_id, :avatar, :avatar_cache, :twitter, :show_twitter, :website, :show_website,
        :show_bikes, :show_phone, :my_bikes_link_target, :my_bikes_link_title, :password,
        :password_confirmation, :preferred_language)
      .merge(sign_in_partner.present? ? {partner_data: {sign_up: sign_in_partner}} : {})
  end

  def permitted_update_parameters
    pparams = permitted_parameters.except(:email)
    if pparams.key?("username")
      pparams.delete("username") unless pparams["username"].present?
    end
    pparams
  end

  def permitted_password_reset_parameters
    params.require(:user).permit(:password, :password_confirmation)
  end

  def edit_templates
    @edit_templates ||= {
      root: translation(:user_settings),
      password: translation(:password),
      sharing: translation(:sharing)
    }.as_json
  end

  def assign_edit_template
    @edit_template = edit_templates[params[:page]].present? ? params[:page] : edit_templates.keys.first
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

  def find_user_from_password_reset_token!
    @token = params[:token]
    @user = User.find_by_password_reset_token(@token) if @token.present?
    return true if @user.present? && !@user.auth_token_expired?("password_reset_token")
    remove_session
    flash[:error] = @user.blank? ? translation(:does_not_match_token) : translation(:token_expired)
    redirect_to(request_password_reset_form_users_path) && return
  end

  def update_user_authentication_for_new_password
    @user.generate_auth_token("auth_token") # Doesn't save user
    @user.update_auth_token("password_reset_token") # saves users
    @user.reload
  end
end
