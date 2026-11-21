class OrganizationSignupController < ApplicationController
  include Sessionable

  SESSION_KEY = :organization_signup_token

  before_action :find_signup, except: %i[new confirm confirm_email]
  before_action :find_signup_for_confirmation, only: %i[confirm confirm_email]
  # The step shown is server state - a cached page could show one the signup is past
  before_action { response.set_header("Cache-Control", "no-store") }
  # Every step is a page, but a Turbo submission asks for a turbo_stream
  before_action :force_html_response

  # Picks up where the session (or a confirmed address) left off - every "sign up your
  # organization" link lands here, including mid-way through
  def new
    @signup = OrgServices::Signup.resumable(token: session[SESSION_KEY], user: current_user) if params[:restart].blank?
    if @signup.blank?
      session.delete(SESSION_KEY)
      @signup = OrgServices::Signup.build(user: current_user, return_to: local_return_to, kind: params[:kind])
      return render(step_page("1"))
    end

    @signup.update(return_to: local_return_to) if local_return_to.present?
    # A link's kind preselects step 1, but never overrides one already chosen
    @signup.update(kind: params[:kind]) if @signup.kind.blank? && Organization.user_creatable_kinds.include?(params[:kind])
    session[SESSION_KEY] = @signup.id_token
    redirect_to organization_signup_path
  end

  def show
    step = OrgServices::Signup.permitted_step(@signup, params[:step])
    return redirect_to(organization_signup_path(step:)) if step != params[:step]

    render step_page(step)
  end

  def create
    start = params.fetch(:organization_signup, {})
    # First, so its error stops save_start saving - a saved step 1 lets the rest of the flow send the email
    turnstile_verified?(@signup, current_user&.email || start[:email])
    saved = OrgServices::Signup.save_start(@signup, user: current_user, name: start[:name], kind: start[:kind],
      email: start[:email], pos_kind: start[:pos_kind], additional: params[:additional])
    return render(step_page("1"), status: :unprocessable_entity) unless saved

    session[SESSION_KEY] = @signup.id_token
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
    # A proven address has nothing to send - what's left is finishing
    return complete_or_details if @signup.email_confirmed?

    if OrgServices::Signup.send_confirmation_email(@signup)
      flash[:success] = translation(:link_resent, email: @signup.email)
    elsif OrgServices::Signup.confirmation_emails_exhausted?(@signup)
      flash[:error] = translation(:no_more_links, email: @signup.email)
    else
      flash[:notice] = translation(:link_recently_sent, email: @signup.email)
    end
    redirect_to organization_signup_path(step: :finished)
  end

  def confirm
    render Pages::OrgSignup::Views::Confirm::Component.new(organization_signup: @signup, token: params[:confirmation_token],
      signed_in_as: (current_user.email if signed_in_as_someone_else?), accept_terms: terms_pending?,
      terms_checked: params[:terms_of_service].present?)
  end

  def confirm_email
    # Single use, so a second click has nothing left to do - new resumes it for whoever it was
    return redirect_to(new_organization_signup_path) if @signup.email_confirmed?

    unless OrgServices::Signup.confirmation_token_valid?(@signup, params[:confirmation_token])
      flash[:error] = if OrgServices::Signup.send_confirmation_email(@signup)
        translation(:link_invalid_resent, email: @signup.email)
      else
        translation(:link_invalid, email: @signup.email)
      end
      return redirect_to(organization_signup_path)
    end

    if terms_pending? && params[:terms_of_service].blank?
      flash[:error] = translation(:accept_terms)
      return redirect_to(confirm_path)
    end

    replaced = OrgServices::Signup.find(session[SESSION_KEY])
    # The only way back to a signup opened in another browser
    session[SESSION_KEY] = @signup.id_token

    if signed_in_as_someone_else?
      # The page says who's signed in, and its button signs them out
      return redirect_to(confirm_path) unless params[:sign_out].present?

      remove_session
      @current_user = nil
      session[SESSION_KEY] = @signup.id_token
      return unless sign_in_email_owner
    elsif current_user.blank?
      return unless sign_in_email_owner
    end

    # Both places this goes say what's next themselves, so signing in doesn't need to
    flash.delete(:notice)
    flash.delete(:success)
    if replaced.present? && replaced != @signup && replaced.organization_id.blank?
      flash[:notice] = translation(:switched_signup, name: @signup.name, replaced_name: replaced.name)
    end
    current_user.update(terms_of_service: true, accepted_vendor_terms_of_service: true) unless current_user.terms_of_service? && current_user.vendor_terms_of_service?
    OrgServices::Signup.confirm_email!(@signup)
    complete_or_details
  end

  private

  def step_page(step)
    case step
    when "finished" then Pages::OrgSignup::Views::StepFinished::Component.new(organization_signup: @signup, current_user:)
    when "2" then Pages::OrgSignup::Views::Step2::Component.new(organization_signup: @signup)
    else Pages::OrgSignup::Views::Step1::Component.new(organization_signup: @signup, current_user:,
      focus_email: params[:change_email].present?)
    end
  end

  def sign_in_email_owner
    return true if sign_in_confirmed_user(@signup.email, return_to: confirm_path).present?

    redirect_to(organization_signup_path) unless performed?
    false
  end

  def confirm_path
    confirm_organization_signup_path(signup_token: @signup.id_token, confirmation_token: params[:confirmation_token],
      terms_of_service: params[:terms_of_service])
  end

  def complete_or_details = @signup.details_completed? ? complete_signup : redirect_to(organization_signup_path(step: 2))

  def email_owner = @email_owner ||= User.fuzzy_confirmed_or_unconfirmed_email_find(@signup.email)

  def signed_in_as_someone_else? = current_user.present? && current_user != email_owner

  # The email's account is the one confirming signs in, whoever's session it is
  def terms_pending? = !(email_owner&.terms_of_service? && email_owner.vendor_terms_of_service?)

  # The confirmed address's account is the admin, whichever browser finishes - one that
  # isn't signed in as it gets the organization made, then has to sign in to manage it
  def complete_signup
    organization = OrgServices::Signup.complete(@signup, user: email_owner)
    if organization.errors.include?(:short_name)
      flash[:error] = translation(:name_taken_meanwhile, controller_method: :complete_signup, name: @signup.name)
      return redirect_to(organization_signup_path(step: 1))
    elsif organization.errors.any?
      # Step 1 checks the name the way Organization does, so anything else isn't theirs to fix
      errors = organization.errors.full_messages
      Honeybadger.notify("Organization signup failed to complete", context: {organization_signup_id: @signup.id, errors:})
      flash[:error] = translation(:unable_to_complete, controller_method: :complete_signup, errors: errors.to_sentence)
      return redirect_to(organization_signup_path(step: 2))
    end

    session.delete(SESSION_KEY)
    # A page of its own rather than straight to return_to: these submissions are fetched,
    # and a fetch can't follow lightspeed_interface's redirect off-site
    info_path = organization_info_path(organization_id: organization.to_param, return_to: @signup.return_to)
    return redirect_to_sign_in_for(organization, after_sign_in: info_path) if current_user != email_owner

    redirect_to info_path
  end

  def redirect_to_sign_in_for(organization, after_sign_in: organization_manage_path(organization_id: organization.to_param))
    email = email_owner&.email || @signup.email
    flash[:notice] = translation(:sign_in_to_manage, controller_method: :redirect_to_sign_in_for, name: organization.name, email:)
    store_return_to(after_sign_in)
    redirect_to new_session_path(email:)
  end

  # Once its organization exists the signup has nothing left to show, so it goes there instead
  def redirect_to_organization(organization)
    return redirect_to_sign_in_for(organization) unless current_user&.admin_of?(organization)

    flash[:notice] = translation(:already_activated, controller_method: :redirect_to_organization, name: organization.name)
    redirect_to organization_manage_path(organization_id: organization.to_param)
  end

  def find_signup
    @signup = OrgServices::Signup.find(session[SESSION_KEY])
    @signup ||= OrgServices::Signup.build(user: current_user, return_to: local_return_to) if action_name == "create"
    return redirect_to(new_organization_signup_path) if @signup.blank?

    redirect_to_organization(@signup.organization) if @signup.organization.present?
  end

  # The emailed token authorizes this, not the session - which confirm_email attaches once it checks out
  def find_signup_for_confirmation
    @signup = OrgServices::Signup.find(params[:signup_token])
    if @signup.blank?
      flash[:notice] = translation(:signup_not_found)
      return redirect_to(new_organization_signup_path(restart: true))
    end

    redirect_to_organization(@signup.organization) if @signup.organization.present?
  end
end
