class RegisterController < ApplicationController
  before_action :find_b_param, except: %i[new]
  before_action :redirect_registered, only: %i[create update]

  # Redirects into step 1 with a token (reusing the session's registration when
  # it's still blank), so going back from step 2 lands on the same registration
  def new
    b_param = reusable_b_param || BParam.create(origin: "registration_flow",
      creator_id: current_user&.id, params: {bike: BParam.status_hash_from_params(params)}.as_json)
    session[:register_b_param_token] = b_param.id_token
    redirect_to step_path(1, b_param)
  end

  # The whole flow after the start: ?step=1, ?step=2 and ?step=complete - or the
  # emailed confirmation link. A step the registration isn't at redirects to one it is.
  def show
    return confirm if params[:confirmation_token].present? && !@b_param.with_bike?

    step = permitted_step
    return redirect_to(step_path(step)) if step != params[:step]

    case step
    when "complete"
      render Register::Complete::Component.new(b_param: @b_param)
    when "2"
      @page_title = I18n.t("meta_titles.register_step_2")
      render Register::Step2::Component.new(b_param: @b_param)
    else
      @page_title = I18n.t("meta_titles.register_step_1")
      render Register::Step1::Component.new(b_param: @b_param)
    end
  end

  def create
    previous_email = @b_param.owner_email
    @b_param.clean_params(create_params.as_json)
    @b_param.errors.add(:base, translation(:email_required)) if @b_param.owner_email.blank?
    @b_param.errors.add(:base, translation(:manufacturer_required)) if @b_param.manufacturer_id.blank?
    if @b_param.errors.any?
      render Register::Step1::Component.new(b_param: @b_param), status: :unprocessable_entity
    elsif @b_param.save
      # Resubmitting step 1 only resends the confirmation email to a new address
      Email::PartialRegistrationJob.perform_async(@b_param.id) if @b_param.owner_email != previous_email
      redirect_to step_path(2)
    else
      @b_param.errors.add(:base, translation(:unable_to_save))
      render Register::Step1::Component.new(b_param: @b_param), status: :unprocessable_entity
    end
  end

  def update
    @b_param.creator_id ||= current_user&.id
    @b_param.clean_params(update_params.as_json)
    @b_param.save
    if creator_available?
      create_bike_and_redirect
    else
      # Everything is saved on the b_param - the bike is created once the
      # confirmation link from the partial registration email is clicked
      redirect_to step_path(:complete)
    end
  end

  private

  def step_path(step, b_param = @b_param)
    register_path(b_param_token: b_param.id_token, step:)
  end

  # complete once the bike exists (or it's awaiting the email), step 1 until
  # it's submitted - then steps 1 and 2 both stay browsable
  def permitted_step
    if @b_param.with_bike? || (@b_param.details_completed? && !creator_available?)
      "complete"
    elsif @b_param.owner_email.blank?
      "1"
    else
      (params[:step] == "1") ? "1" : "2"
    end
  end

  # The tokenized link from the partial registration email - proves control of the email
  def confirm
    unless secure_compare?(params[:confirmation_token], @b_param.confirmation_token)
      flash[:error] = translation(:invalid_confirmation_link)
      return redirect_to(new_register_path)
    end
    @b_param.confirm_email!
    if @b_param.details_completed?
      create_bike_and_redirect
    else
      flash[:success] = translation(:email_confirmed_add_details)
      redirect_to step_path(2)
    end
  end

  def find_b_param
    @b_param = BParam.find_for_token(params[:b_param_token], user_id: current_user&.id)
    return if @b_param.present?

    flash[:info] = translation(:registration_not_found) if params[:b_param_token].present?
    redirect_to new_register_path
  end

  # Once the bike exists the token only ever shows the completion page
  def redirect_registered
    redirect_to step_path(:complete) if @b_param.with_bike?
  end

  # The session's registration, as long as it hasn't gotten anywhere - step 1
  # never submitted, so redirecting into it can't surprise anyone
  def reusable_b_param
    token = session[:register_b_param_token]
    return if token.blank?

    b_param = BParam.find_for_token(token, user_id: current_user&.id)
    b_param if b_param.present? && !b_param.with_bike? && b_param.owner_email.blank?
  end

  def creator_available?
    @b_param.creator_id.present? || @b_param.creation_organization&.auto_user_id.present? ||
      confirmed_email_creator_id.present?
  end

  def confirmed_email_creator_id
    return @confirmed_email_creator_id if defined?(@confirmed_email_creator_id)

    @confirmed_email_creator_id = @b_param.confirmed_email_creator_id
  end

  def create_bike_and_redirect
    @b_param.creator_id ||= confirmed_email_creator_id
    bike = BikeServices::Creator.new(ip_address: forwarded_ip_address).create_bike(@b_param)
    if bike.errors.any?
      flash[:error] = @b_param.bike_errors&.to_sentence
      redirect_to step_path(2)
    else
      redirect_to step_path(:complete)
    end
  end

  def create_params
    bike_params = params.require(:b_param).permit(:manufacturer_id, :cycle_type, :owner_email)
      .to_h.merge(BParam.status_hash_from_params(params))
    bike_params[:creation_organization_id] = current_organization.id if current_organization.present?
    {bike: bike_params, propulsion_type_motorized: params[:propulsion_type_motorized]}
  end

  # Blank values are dropped rather than overwriting what step 1 saved - except the
  # additional colors, where blank is the "remove color" button clearing one
  def update_params
    bike_params = params.fetch(:bike, {}).permit(:primary_frame_color_id, :secondary_frame_color_id,
      :tertiary_frame_color_id, :serial_number, :frame_size, :frame_size_number, :frame_size_unit,
      :bike_sticker, :phone, :status, :frame_model, :year)
      .reject { |key, value| value.blank? && !key.in?(%w[secondary_frame_color_id tertiary_frame_color_id]) }
    # The unit only means something alongside a numeric size
    bike_params.delete("frame_size_unit") if bike_params["frame_size_number"].blank?
    # The photo went browser -> bucket before submit, so only its signed id rides along.
    # Dropped when blank rather than merged, which would clobber an id already stored.
    {details_completed: true, bike: bike_params,
     image_signed_id: params[:image_signed_id].presence}.compact
  end
end
