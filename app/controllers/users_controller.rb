class UsersController < ApplicationController
  include Sessionable
  before_action :authenticate_user, only: [:edit]
  before_action :skip_if_signed_in, only: [:new, :globalid]
  before_action :assign_edit_template, only: [:edit, :update]

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
    redirect_to(user_root_url) and return if current_user.present?
    @user = unconfirmed_current_user
    layout = sign_in_partner == "bikehub" ? "application_bikehub" : "application"
  end

  def confirm
    begin
      @user = User.find(params[:id])
      if @user.confirmed?
        flash[:success] = translation(:already_confirmed)
        # If signed in, redirect to partner if it should
        if current_user.present? && sign_in_partner.present?
          session.delete(:partner) # Only removing once signed in, PR#1435
          redirect_to bikehub_url("account?reauthenticate_bike_index=true") and return # Only partner rn is bikehub, hardcode it
        else
          render_partner_or_default_signin_layout(redirect_path: new_session_path)
        end
      else
        if @user.confirm(params[:code])
          sign_in_and_redirect(@user)
        else
          render :confirm_error_bad_token
        end
      end
    rescue ActiveRecord::RecordNotFound
      render :confirm_error_404
    end
  end

  def request_password_reset
  end

  def update_password
    @user = current_user
  end

  def password_reset
    if params[:token].present?
      @user = User.find_by_password_reset_token(params[:token])
      if @user.present? && !@user.auth_token_expired?("password_reset_token")
        session[:return_to] = "password_reset"
        # They got the password reset email, which counts as confirming their email
        @user.confirm(@user.confirmation_token) if @user.unconfirmed?
        sign_in_and_redirect(@user)
      else
        flash[:error] = translation(:link_no_longer_valid)
        render action: :request_password_reset
      end
    elsif params[:email].present?
      @user = User.fuzzy_confirmed_or_unconfirmed_email_find(params[:email])
      if @user.present?
        @user.send_password_reset_email
      else
        flash[:error] = translation(:email_not_found)
        render action: :request_password_reset
      end
    else
      redirect_to request_password_reset_users_url
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
      redirect_to user_home_url, notice: translation(:user_not_sharing) and return
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
    if params[:user][:password_reset_token].present?
      if @user.password_reset_token != params[:user][:password_reset_token]
        remove_session
        flash[:error] = translation(:does_not_match_token)
        redirect_to user_home_url and return
      elsif @user.auth_token_expired?("password_reset_token")
        remove_session
        flash[:error] = translation(:token_expired)
        redirect_to user_home_url and return
      end
    elsif params[:user][:password].present?
      unless @user.authenticate(params[:user][:current_password])
        @user.errors.add(:base, translation(:current_password_doesnt_match))
      end
    end
    if !@user.errors.any? && @user.update_attributes(permitted_update_parameters)
      AfterUserChangeWorker.perform_async(@user.id)
      if params[:user][:terms_of_service].present?
        if ParamsNormalizer.boolean(params[:user][:terms_of_service])
          @user.terms_of_service = true
          @user.save
          flash[:success] = translation(:you_can_use_bike_index)
          redirect_to user_home_url and return
        else
          flash[:notice] = translation(:accept_tos)
          redirect_to accept_terms_url and return
        end
      elsif params[:user][:vendor_terms_of_service].present?
        if ParamsNormalizer.boolean(params[:user][:vendor_terms_of_service])
          @user.update_attributes(accepted_vendor_terms_of_service: true)
          if @user.memberships.any?
            flash[:success] = translation(:you_can_use_bike_index_as_org, org_name: @user.memberships.first.organization.name)
          else
            flash[:success] = translation(:thanks_for_accepting_tos)
          end
          redirect_to user_root_url and return
        else
          redirect_to accept_vendor_terms_path, notice: translation(:accept_tos_to_use_as_org) and return
        end
      end
      if params[:user][:password].present?
        @user.generate_auth_token("auth_token")
        @user.update_auth_token("password_reset_token")
        @user.reload
        default_session_set(@user)
      end
      flash[:success] = translation(:successfully_updated)
      redirect_to my_account_url(page: params[:page]) and return
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
    redirect_to user_root_url and return
  end

  private

  def permitted_parameters
    params.require(:user)
          .permit(:name, :username, :email, :notification_newsletters, :notification_unstolen, :terms_of_service,
                  :additional_emails, :title, :description, :phone, :street, :city, :zipcode, :country_id,
                  :state_id, :avatar, :avatar_cache, :twitter, :show_twitter, :website, :show_website,
                  :show_bikes, :show_phone, :my_bikes_link_target, :my_bikes_link_title, :password,
                  :password_confirmation, :preferred_language)
          .merge(sign_in_partner.present? ? { partner_data: { sign_up: sign_in_partner } } : {})
  end

  def permitted_update_parameters
    pparams = permitted_parameters.except(:email, :password_reset_token)
    if pparams.keys.include?("username")
      pparams.delete("username") unless pparams["username"].present?
    end
    pparams
  end

  def edit_templates
    @edit_templates ||= {
      root: translation(:user_settings),
      password: translation(:password),
      sharing: translation(:sharing),
    }.as_json
  end

  def assign_edit_template
    @edit_template = edit_templates[params[:page]].present? ? params[:page] : edit_templates.keys.first
  end
end
