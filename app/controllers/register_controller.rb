class RegisterController < ApplicationController
  include Sessionable

  before_action :find_b_param, except: %i[new create confirm confirm_email]
  # An expired token starts a registration rather than bouncing and losing the
  # submission. assign_organization runs next, so the form's organization_id lands on it
  before_action -> { find_b_param(build: true) }, only: %i[create]
  # The emailed link resumes a registration the session knows nothing about
  before_action :find_b_param_for_confirmation, only: %i[confirm confirm_email]
  # confirm renders a self-posting form and nothing else, so it reads neither
  before_action :assign_organization, except: %i[new confirm]
  before_action :find_registration_sequence, except: %i[new confirm]
  before_action :redirect_finished, only: %i[create update acknowledge]
  # The step shown depends on server state - a cached page could show a step
  # the registration is past (register--revalidate covers Safari's bfcache)
  before_action { response.set_header("Cache-Control", "no-store") }

  # Redirects into step 1 with a token (reusing the session's registration when
  # it's still blank), so going back from step 2 lands on the same registration
  def new
    @b_param = BikeServices::Register.b_param_for(user: current_user, token_id: reusable_token,
      status: params[:status], email: params[:email])
    # The same filter every other action runs, so reusing the session's
    # registration can't quietly drop the organization the URL named
    assign_organization
    session[:register_b_param_token] = @b_param.id_token
    redirect_to step_path(1)
  end

  # The whole flow after the start: ?step=1, ?step=2, the e-vehicle acknowledgment
  # pages (?step=3 up), ?step=review and ?step=finished. A step the registration
  # isn't at redirects to one it is.
  def show
    step = BikeServices::Register.permitted_step(@b_param, params[:step], sequence: @registration_sequence)
    return redirect_to(step_path(step)) if step != params[:step]

    case step
    when "finished"
      @page_title = I18n.t("meta_titles.register_show", cycle_type: @b_param.type_titleize)
      render Register::StepFinished::Component.new(b_param: @b_param, current_user:)
    when "review"
      @page_title = I18n.t("meta_titles.register_review", cycle_type: @b_param.type)
      render Register::StepReview::Component.new(b_param: @b_param, sequence: @registration_sequence, current_user:)
    when "2"
      @page_title = I18n.t("meta_titles.register_step_2", cycle_type: @b_param.type)
      render Register::Step2::Component.new(b_param: @b_param, sequence: @registration_sequence, current_user:)
    when "1"
      @page_title = I18n.t("meta_titles.register_step_1", cycle_type: @b_param.type)
      render Register::Step1::Component.new(b_param: @b_param, sequence: @registration_sequence, current_user:)
    else
      @page_title = I18n.t("meta_titles.register_acknowledgment", cycle_type: @b_param.type)
      render Register::StepAcknowledgment::Component.new(b_param: @b_param, sequence: @registration_sequence, step:)
    end
  end

  def create
    saved = BikeServices::Register.save_step_1(@b_param, bike_params: create_params,
      propulsion_type_motorized: params[:propulsion_type_motorized])
    unless saved
      # The 422 render skips the derived meta title, which now needs the interpolation
      @page_title = I18n.t("meta_titles.register_create", cycle_type: @b_param.type)
      return render(Register::Step1::Component.new(b_param: @b_param, sequence: @registration_sequence, current_user:),
        status: :unprocessable_entity)
    end

    # Step 2 says the link is on its way, so it goes out here rather than at the end
    BikeServices::Register.send_confirmation_email(@b_param)
    redirect_to step_path(2)
  end

  def update
    # Both read straight from params - update_params is stored as json, which an upload can't be
    saved = BikeServices::Register.save_step_2(@b_param, user: current_user,
      image: params.dig(:bike, :image), image_signed_id: params.dig(:bike, :image_signed_id),
      bike_params: update_params)
    # Saved either way, so the re-render has everything they entered
    unless saved
      return render(Register::Step2::Component.new(b_param: @b_param, sequence: @registration_sequence, current_user:),
        status: :unprocessable_entity)
    end

    complete_registration
  end

  # Each acknowledgment page posts here, and the review's final acknowledgment
  def acknowledge
    step = BikeServices::Register.permitted_step(@b_param, params[:step], sequence: @registration_sequence)
    acknowledged = BikeServices::Register.acknowledge_step(@b_param, step,
      sequence: @registration_sequence, user: current_user,
      acknowledged_all: params[:acknowledged_all], checked: params[:acknowledged]&.to_unsafe_h&.values)
    unless acknowledged
      flash[:error] = translation(:acknowledge_everything)
      return redirect_to step_path(step)
    end
    return complete_registration if step == "review"

    # The step after this one, not the furthest reached - revisiting an earlier page
    # from the review walks forward through the rest rather than jumping back
    redirect_to step_path(BikeServices::Register.step_after(step, sequence: @registration_sequence))
  end

  def confirm
    @page_title = I18n.t("meta_titles.register_confirm")
    render Register::Confirm::Component.new(b_param: @b_param, token: params[:confirmation_token])
  end

  # The confirmation itself - the proven address gets an account, created here if
  # this is their first registration
  def confirm_email
    # Single use, so a second click has nothing left to do - the first one signed them in
    return redirect_to_current_step if @b_param.email_confirmed?

    unless BikeServices::Register.confirmation_token_valid?(@b_param, params[:confirmation_token])
      BikeServices::Register.send_confirmation_email(@b_param)
      flash[:error] = translation(:confirmation_link_expired)
      return redirect_to_current_step
    end

    # Someone else's session stays theirs - the registration is still finished for the
    # address that was emailed, it just isn't that account's own
    if current_user.present?
      flash[:notice] = translation(:signed_in_as_other, email: current_user.email) unless @b_param.self_made?(current_user)
    elsif sign_in_confirmed_user.blank?
      return redirect_to_current_step
    end

    @b_param.confirm_email!(creator_id: current_user.id)
    complete_registration
  end

  private

  def complete_registration
    bike = BikeServices::Register.complete(@b_param, user: current_user,
      sequence: @registration_sequence, ip_address: forwarded_ip_address)
    # No bike yet - everything stays on the b_param until the flow's remaining steps are done
    return redirect_to_current_step if bike.blank?

    redirect_after_bike_creation(bike)
  end

  # The account the confirmed address belongs to, created if it doesn't have one yet
  def sign_in_confirmed_user
    user, signed_up = UserServices::PasswordlessCreator.find_or_create(@b_param.owner_email)
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

  # Wherever the registration now stands: the next unacknowledged page, or the review
  def redirect_to_current_step
    redirect_to step_path(BikeServices::Register.permitted_step(@b_param, nil, sequence: @registration_sequence))
  end

  def step_path(step)
    register_path(b_param_token: @b_param.id_token, step:)
  end

  # Everything new seeds a registration from, so arriving on an organization's link
  # (or a stolen one) without a registration doesn't lose how they got there
  def start_params
    params.permit(:organization_id, :status, :email).to_h.compact_blank
  end

  # b_param_token=false abandons the session's registration - the start over link
  def reusable_token
    session[:register_b_param_token] unless params[:b_param_token] == "false"
  end

  def assign_organization
    BikeServices::Register.assign_organization(@b_param, current_organization)
  end

  # Resolved once - the step math, the progress bar and the pages themselves all read it
  def find_registration_sequence
    @registration_sequence = BikeServices::Register.registration_sequence(@b_param)
  end

  # Not find_b_param: the emailed token authorizes this, not the session, and an expired
  # link has to find its registration to say so rather than dead-end. Nothing is written
  # to the session - the token hasn't been checked yet
  def find_b_param_for_confirmation
    token = params[:b_param_token]
    @b_param = BParam.find_by(id_token: token) if token.present?
    redirect_to(new_register_path) if @b_param.blank?
  end

  # build: only step 1's submission, which carries everything a registration needs
  def find_b_param(build: false)
    @b_param = BikeServices::Register.find_token(params_token: params[:b_param_token],
      session_token: session[:register_b_param_token], user: current_user)
    @b_param ||= BikeServices::Register.b_param_for(user: current_user) if build
    if @b_param.blank?
      flash[:notice] = translation(:registration_not_found) if params[:b_param_token].present?
      return redirect_to(new_register_path(start_params))
    end

    # The session follows whichever registration the token named, so the next
    # tokenless request stays on it
    session[:register_b_param_token] = @b_param.id_token
  end

  # A finished registration (bike created, or awaiting the email) only shows
  # the completion page - submissions redirect there too, saving nothing
  def redirect_finished
    redirect_to step_path(:finished) if BikeServices::Register.finished?(@b_param, sequence: @registration_sequence)
  end

  def redirect_after_bike_creation(bike)
    if bike.errors.any?
      flash[:error] = @b_param.bike_errors&.to_sentence
      redirect_to step_path(2)
    else
      redirect_to step_path(:finished)
    end
  end

  def create_params
    params.require(:b_param).permit(:manufacturer_id, :cycle_type, :owner_email)
      .to_h.merge(BParam.status_hash_from_params(params))
  end

  def update_params
    params.fetch(:bike, {}).permit(:primary_frame_color_id, :secondary_frame_color_id,
      :tertiary_frame_color_id, :serial_number, :frame_size, :frame_size_number, :frame_size_unit,
      :bike_sticker, :phone, :status, :frame_model, :year, :user_name,
      :extra_registration_number, :organization_affiliation, :student_id,
      address_record_attributes: AddressRecord.permitted_params)
  end
end
