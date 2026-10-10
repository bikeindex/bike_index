class OrganizationSignupController < ApplicationController
  include Sessionable

  SESSION_KEY = :organization_signup_token

  before_action :find_signup, except: %i[new confirm confirm_email welcome]
  before_action :find_signup_for_confirmation, only: %i[confirm confirm_email]
  # The step shown is server state - a cached page could show one the signup is past
  before_action { response.set_header("Cache-Control", "no-store") }
  # Every step is a page, but a Turbo submission asks for a turbo_stream
  before_action :force_html_response

  # Picks up where the session (or a confirmed address) left off - every "sign up your
  # organization" link lands here, including mid-way through
  def new
    signup = OrgServices::Signup.resumable(token: session[SESSION_KEY], user: current_user) if params[:restart].blank?
    signup ||= OrgServices::Signup.start(user: current_user)
    signup.update(return_to:) if return_to.present?
    session[SESSION_KEY] = signup.id_token
    redirect_to organization_signup_path
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
    # Renamed after the name was taken at activation
    return complete_signup if OrgServices::Signup.ready_to_complete?(@signup)

    # Step 2 says the link is on its way, so it goes out here rather than at the end
    OrgServices::Signup.send_confirmation_email(@signup)
    redirect_to organization_signup_path(step: @signup.details_completed? ? :finished : 2)
  end

  def update
    details = params.fetch(:organization_signup, {})
    saved = OrgServices::Signup.save_details(@signup, website: details[:website], phone: details[:phone],
      publicly_visible: details[:publicly_visible],
      address: details.fetch(:address_record_attributes, {}).permit(*AddressRecord.permitted_params))
    return render(step_page("2"), status: :unprocessable_entity) unless saved
    # The link was clicked before this was finished - possibly in another browser
    return complete_signup if @signup.email_confirmed?

    redirect_to organization_signup_path(step: :finished)
  end

  # Rate limited, so a second press says the link is on its way rather than sending another
  def resend
    if OrgServices::Signup.send_confirmation_email(@signup)
      flash[:success] = translation(:link_resent, email: @signup.email)
    else
      flash[:notice] = translation(:link_recently_sent, email: @signup.email)
    end
    redirect_to organization_signup_path(step: :finished)
  end

  def confirm
    render Pages::OrgSignup::Views::Confirm::Component.new(organization_signup: @signup, token: params[:confirmation_token],
      signed_in_as: (current_user.email if signed_in_as_someone_else?))
  end

  def confirm_email
    # Single use, so a second click has nothing left to do
    return redirect_to(organization_signup_path) if @signup.email_confirmed?

    unless OrgServices::Signup.confirmation_token_valid?(@signup, params[:confirmation_token])
      flash[:error] = if OrgServices::Signup.send_confirmation_email(@signup)
        translation(:link_invalid_resent, email: @signup.email)
      else
        translation(:link_invalid, email: @signup.email)
      end
      return redirect_to(organization_signup_path)
    end

    if signed_in_as_someone_else?
      unless params[:sign_out].present?
        flash[:error] = translation(:sign_out_to_confirm, email: current_user.email)
        return redirect_to(confirm_organization_signup_path(signup_token: @signup.id_token,
          confirmation_token: params[:confirmation_token]))
      end

      remove_session
      @current_user = nil
      session[SESSION_KEY] = @signup.id_token
      return redirect_to(organization_signup_path) if sign_in_confirmed_user(@signup.email).blank?
    elsif current_user.blank? && sign_in_confirmed_user(@signup.email).blank?
      return redirect_to(organization_signup_path)
    end

    # Both places this goes say what's next themselves, so signing in doesn't need to
    flash.delete(:notice)
    flash.delete(:success)
    OrgServices::Signup.confirm_email!(@signup)
    return redirect_to(organization_signup_path(step: 2)) unless @signup.details_completed?

    complete_signup
  end

  def welcome
    @organization = Organization.friendly_find(params[:organization_id])
    return authenticate_user(flash_type: :notice) if current_user.blank?
    return redirect_to(user_root_url) unless current_user.admin_of?(@organization)

    render Pages::OrgSignup::Views::Welcome::Component.new(organization: @organization, current_user:, return_to:)
  end

  private

  def step_page(step)
    case step
    when "finished" then Pages::OrgSignup::Views::StepFinished::Component.new(organization_signup: @signup)
    when "2" then Pages::OrgSignup::Views::Step2::Component.new(organization_signup: @signup)
    else Pages::OrgSignup::Views::Step1::Component.new(organization_signup: @signup, current_user:)
    end
  end

  # Only a path of our own, so a link can't send a new admin off-site
  def return_to
    params[:return_to] if params[:return_to].to_s.match?(%r{\A/(?!/)})
  end

  def email_owner = @email_owner ||= User.fuzzy_confirmed_or_unconfirmed_email_find(@signup.email)

  def signed_in_as_someone_else? = current_user.present? && current_user != email_owner

  # The confirmed address's account is the admin, whichever browser finishes - one that
  # isn't signed in as it gets the organization made, then has to sign in to manage it
  def complete_signup
    organization = OrgServices::Signup.complete(@signup, user: email_owner)
    if organization.errors.any?
      flash[:error] = if organization.errors.include?(:short_name)
        translation(:name_taken_meanwhile, controller_method: :complete_signup, name: @signup.name)
      else
        organization.errors.full_messages.to_sentence
      end
      return redirect_to(organization_signup_path(step: 1))
    end

    session.delete(SESSION_KEY)
    return redirect_to_sign_in_for(organization) if current_user != email_owner

    # A page of its own rather than straight to return_to: these submissions are fetched,
    # and a fetch can't follow lightspeed_interface's redirect off-site
    redirect_to welcome_organization_signup_path(organization_id: organization.to_param, return_to: @signup.return_to)
  end

  def redirect_to_sign_in_for(organization)
    flash[:notice] = translation(:sign_in_to_manage, controller_method: :redirect_to_sign_in_for, name: organization.name,
      email: email_owner&.email || @signup.email)
    store_return_to(organization_manage_path(organization_id: organization.to_param))
    redirect_to new_session_path
  end

  # Once its organization exists the signup has nothing left to show, so it goes there instead
  def redirect_to_organization(organization)
    return redirect_to_sign_in_for(organization) unless current_user&.admin_of?(organization)

    flash[:notice] = translation(:already_activated, controller_method: :redirect_to_organization, name: organization.name)
    redirect_to organization_manage_path(organization_id: organization.to_param)
  end

  def find_signup
    @signup = OrgServices::Signup.find(session[SESSION_KEY])
    return redirect_to(new_organization_signup_path) if @signup.blank?

    redirect_to_organization(@signup.organization) if @signup.organization.present?
  end

  # The emailed token authorizes this, not the session - which follows it, since it's the
  # only way back to a signup opened in another browser
  def find_signup_for_confirmation
    @signup = OrgServices::Signup.find(params[:signup_token])
    if @signup.blank?
      flash[:notice] = translation(:signup_not_found)
      return redirect_to(new_organization_signup_path(restart: true))
    end
    return redirect_to_organization(@signup.organization) if @signup.organization.present?

    session[SESSION_KEY] = @signup.id_token if action_name == "confirm_email"
  end
end
