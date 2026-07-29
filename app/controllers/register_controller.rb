class RegisterController < ApplicationController
  before_action :find_b_param, except: %i[new create]
  # An expired token starts a registration rather than bouncing and losing the
  # submission. assign_organization runs next, so the form's organization_id lands on it
  before_action -> { find_b_param(build: true) }, only: %i[create]
  before_action :assign_organization, except: %i[new]
  before_action :redirect_finished, only: %i[create update]
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

  # The whole flow after the start: ?step=1, ?step=2 and ?step=finished. A step the
  # registration isn't at redirects to one it is.
  def show
    step = BikeServices::Register.permitted_step(@b_param, params[:step])
    return redirect_to(step_path(step)) if step != params[:step]

    case step
    when "finished"
      @page_title = I18n.t("meta_titles.register_show", cycle_type: @b_param.type_titleize)
      render Register::StepFinished::Component.new(b_param: @b_param, current_user:)
    when "2"
      @page_title = I18n.t("meta_titles.register_step_2", cycle_type: @b_param.type)
      render Register::Step2::Component.new(b_param: @b_param, current_user:)
    else
      @page_title = I18n.t("meta_titles.register_step_1", cycle_type: @b_param.type)
      render Register::Step1::Component.new(b_param: @b_param, current_user:)
    end
  end

  def create
    @b_param.clean_params(create_params.as_json)
    # The 422 renders skip the derived meta title, which now needs the interpolation
    @page_title = I18n.t("meta_titles.register_create", cycle_type: @b_param.type)
    @b_param.errors.add(:base, translation(:email_required)) if @b_param.owner_email.blank?
    @b_param.errors.add(:base, translation(:manufacturer_required)) if @b_param.manufacturer_id.blank?
    if @b_param.errors.any?
      render Register::Step1::Component.new(b_param: @b_param, current_user:), status: :unprocessable_entity
    elsif @b_param.save
      redirect_to step_path(2)
    else
      @b_param.errors.add(:base, translation(:unable_to_save))
      render Register::Step1::Component.new(b_param: @b_param, current_user:), status: :unprocessable_entity
    end
  end

  def update
    BikeServices::Register.save_step_2(@b_param, user: current_user,
      image_signed_id: params[:image_signed_id], bike_params: update_params)
    if BikeServices::Register.creator_available?(@b_param)
      redirect_after_bike_creation(BikeServices::Register.create_bike(@b_param, ip_address: forwarded_ip_address))
    else
      # Everything is saved on the b_param - the bike is created once the
      # confirmation link from the partial registration email is clicked
      redirect_to step_path(:finished)
    end
  end

  private

  def step_path(step)
    register_path(b_param_token: @b_param.id_token, step:)
  end

  # b_param_token=false abandons the session's registration - the start over link
  def reusable_token
    session[:register_b_param_token] unless params[:b_param_token] == "false"
  end

  def assign_organization
    BikeServices::Register.assign_organization(@b_param, current_organization)
  end

  # build: only step 1's submission, which carries everything a registration needs
  def find_b_param(build: false)
    @b_param = BikeServices::Register.find_token(params_token: params[:b_param_token],
      session_token: session[:register_b_param_token], user: current_user)
    @b_param ||= BikeServices::Register.b_param_for(user: current_user) if build
    if @b_param.blank?
      flash[:info] = translation(:registration_not_found) if params[:b_param_token].present?
      return redirect_to(new_register_path)
    end

    # The session follows whichever registration the token named, so the next
    # tokenless request stays on it
    session[:register_b_param_token] = @b_param.id_token
  end

  # A finished registration (bike created, or awaiting the email) only shows
  # the completion page - submissions redirect there too, saving nothing
  def redirect_finished
    redirect_to step_path(:finished) if BikeServices::Register.finished?(@b_param)
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
    bike_params = params.require(:b_param).permit(:manufacturer_id, :cycle_type, :owner_email)
      .to_h.merge(BParam.status_hash_from_params(params))
    {bike: bike_params, propulsion_type_motorized: params[:propulsion_type_motorized]}
  end

  def update_params
    params.fetch(:bike, {}).permit(:primary_frame_color_id, :secondary_frame_color_id,
      :tertiary_frame_color_id, :serial_number, :frame_size, :frame_size_number, :frame_size_unit,
      :bike_sticker, :phone, :status, :frame_model, :year,
      :extra_registration_number, :organization_affiliation, :student_id,
      address_record_attributes: AddressRecord.permitted_params)
  end
end
