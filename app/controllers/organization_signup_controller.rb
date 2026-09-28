class OrganizationSignupController < ApplicationController
  include Sessionable

  SESSION_KEY = :organization_signup_token

  before_action :find_signup, except: %i[new confirm confirm_email]
  # The emailed link resumes a signup the session may know nothing about
  before_action :find_signup_for_confirmation, only: %i[confirm confirm_email]
  # The step shown is server state - a cached page could show one the signup is past
  before_action { response.set_header("Cache-Control", "no-store") }
  # Every step is a page, but a Turbo submission asks for a turbo_stream
  before_action :force_html_response

  def new
    signup = OrgServices::Signup.start(user: current_user)
    session[SESSION_KEY] = signup.id_token
    redirect_to organization_signup_path(step: 1)
  end

  def show
    step = OrgServices::Signup.permitted_step(@signup, params[:step])
    return redirect_to(organization_signup_path(step:)) if step != params[:step]

    render step_page(step)
  end

  def create
    saved = OrgServices::Signup.save_start(@signup, user: current_user, name: params.dig(:organization_signup, :name),
      kind: params.dig(:organization_signup, :kind), email: params.dig(:organization_signup, :email),
      additional: params[:additional]) && turnstile_verified?(@signup, @signup.email)
    return render(step_page("1"), status: :unprocessable_entity) unless saved

    # Step 2 says the link is on its way, so it goes out here rather than at the end
    OrgServices::Signup.send_confirmation_email(@signup)
    redirect_to organization_signup_path(step: 2)
  end

  def update
    details = params.fetch(:organization_signup, {})
    saved = OrgServices::Signup.save_details(@signup, website: details[:website], phone: details[:phone],
      publicly_visible: details[:publicly_visible],
      address: details.fetch(:address_record_attributes, {}).permit(*AddressRecord.permitted_params))
    return render(step_page("2"), status: :unprocessable_entity) unless saved
    # Clicked the link before finishing, so this is the last thing standing in the way
    return complete_signup if @signup.email_confirmed? && current_user.present?

    redirect_to organization_signup_path(step: :finished)
  end

  def confirm
    render Pages::OrgSignup::Views::Confirm::Component.new(organization_signup: @signup, token: params[:confirmation_token])
  end

  # The confirmation itself - the proven address gets an account, created here if it
  # doesn't have one, and then the organization
  def confirm_email
    # Single use, so a second click has nothing left to do
    return redirect_to(organization_signup_path) if @signup.email_confirmed?

    unless OrgServices::Signup.confirmation_token_valid?(@signup, params[:confirmation_token])
      OrgServices::Signup.send_confirmation_email(@signup)
      flash[:error] = translation(:confirmation_link_expired)
      return redirect_to(organization_signup_path)
    end

    user = User.fuzzy_confirmed_or_unconfirmed_email_find(@signup.email)
    if current_user.present? && current_user != user
      flash[:error] = translation(:sign_out_to_confirm, email: current_user.email)
      return redirect_to(confirm_organization_signup_path(signup_token: @signup.id_token,
        confirmation_token: params[:confirmation_token]))
    end
    return redirect_to(organization_signup_path) if current_user.blank? && sign_in_confirmed_user.blank?

    OrgServices::Signup.confirm_email!(@signup)
    return redirect_to(organization_signup_path(step: 2)) unless @signup.details_completed?

    complete_signup
  end

  private

  def step_page(step)
    case step
    when "finished" then Pages::OrgSignup::Views::StepFinished::Component.new(organization_signup: @signup)
    when "2" then Pages::OrgSignup::Views::Step2::Component.new(organization_signup: @signup)
    else Pages::OrgSignup::Views::Step1::Component.new(organization_signup: @signup, current_user:)
    end
  end

  def complete_signup
    organization = OrgServices::Signup.complete(@signup, user: current_user)
    if organization.errors.any?
      flash[:error] = organization.errors.full_messages.to_sentence
      return redirect_to(organization_signup_path(step: 1))
    end

    session.delete(SESSION_KEY)
    flash[:success] = translation(:organization_created, controller_method: :complete_signup, name: organization.name)
    # lightspeed_interface sends people here to come back once they have an organization
    redirect_to organization_manage_path(organization_id: organization.to_param) unless return_to_if_present
  end

  # The account the confirmed address belongs to, created if it doesn't have one yet
  def sign_in_confirmed_user
    user, signed_up = UserServices::PasswordlessCreator.find_or_create(@signup.email)
    if user.blank? || user.banned?
      flash[:error] = translation(:unable_to_sign_in)
      return nil
    end

    # The link proved the address, so an account that had never confirmed it now has
    user.confirm(user.confirmation_token) unless user.confirmed?
    sign_in_user(user)
    set_sign_in_flash(user, signed_up)
    @current_user = user
  end

  def find_signup
    @signup = OrgServices::Signup.find(session[SESSION_KEY])
    redirect_to(new_organization_signup_path) if @signup.blank?
  end

  # Not find_signup: the emailed token authorizes this, not the session - which follows it,
  # since it's the only way back to a signup opened in another browser
  def find_signup_for_confirmation
    signup = OrganizationSignup.find_by(id_token: params[:signup_token]) if params[:signup_token].present?
    if signup&.with_organization?
      flash[:notice] = translation(:already_activated, controller_method: :find_signup_for_confirmation)
      return redirect_to(organization_manage_path(organization_id: signup.organization.to_param))
    end

    @signup = OrgServices::Signup.find(signup&.id_token)
    if @signup.blank?
      flash[:notice] = translation(:signup_not_found, controller_method: :find_signup_for_confirmation)
      return redirect_to(new_organization_signup_path)
    end

    session[SESSION_KEY] = @signup.id_token if action_name == "confirm_email"
  end
end
