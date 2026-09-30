class OrganizationSignupController < ApplicationController
  include Sessionable

  SESSION_KEY = :organization_signup_token

  before_action :find_signup, except: %i[new confirm confirm_email]
  before_action :find_signup_for_confirmation, only: %i[confirm confirm_email]
  # The step shown is server state - a cached page could show one the signup is past
  before_action { response.set_header("Cache-Control", "no-store") }
  # Every step is a page, but a Turbo submission asks for a turbo_stream
  before_action :force_html_response

  def new
    # Only a path of our own, so the link can't send a new admin off-site
    return_to = params[:return_to] if params[:return_to].to_s.match?(%r{\A/(?!/)})
    signup = OrgServices::Signup.start(user: current_user, return_to:)
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

  def confirm_email
    # Single use, so a second click has nothing left to do
    return redirect_to(organization_signup_path) if @signup.email_confirmed?

    unless OrgServices::Signup.confirmation_token_valid?(@signup, params[:confirmation_token])
      OrgServices::Signup.send_confirmation_email(@signup)
      flash[:error] = translation(:confirmation_link_expired)
      return redirect_to(organization_signup_path)
    end

    if current_user.present? && current_user != User.fuzzy_confirmed_or_unconfirmed_email_find(@signup.email)
      flash[:error] = translation(:sign_out_to_confirm, email: current_user.email)
      return redirect_to(confirm_organization_signup_path(signup_token: @signup.id_token,
        confirmation_token: params[:confirmation_token]))
    end
    return redirect_to(organization_signup_path) if current_user.blank? && sign_in_confirmed_user(@signup.email).blank?

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
    redirect_to @signup.return_to || organization_manage_path(organization_id: organization.to_param)
  end

  def find_signup
    @signup = OrgServices::Signup.find(session[SESSION_KEY])
    redirect_to(new_organization_signup_path) if @signup.blank?
  end

  # The emailed token authorizes this, not the session - which follows it, since it's the
  # only way back to a signup opened in another browser
  def find_signup_for_confirmation
    @signup = OrganizationSignup.find_by(id_token: params[:signup_token]) if params[:signup_token].present?
    if @signup&.organization.present?
      flash[:notice] = translation(:already_activated)
      return redirect_to(organization_manage_path(organization_id: @signup.organization.to_param))
    elsif @signup.blank? || @signup.expired?
      flash[:notice] = translation(:signup_not_found)
      return redirect_to(new_organization_signup_path)
    end

    session[SESSION_KEY] = @signup.id_token if action_name == "confirm_email"
  end
end
