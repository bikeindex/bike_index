class RegisterController < ApplicationController
  before_action :find_b_param, only: %i[show update]

  def new
    b_param = BParam.new(params: {bike: BParam.status_hash_from_params(params)}.as_json)
    render Register::StartForm::Component.new(b_param:)
  end

  def create
    @b_param = BParam.new(origin: "registration_flow", creator_id: current_user&.id,
      params: create_params.as_json)
    @b_param.errors.add(:owner_email, translation(:email_required)) if @b_param.owner_email.blank?
    @b_param.errors.add(:base, translation(:manufacturer_required)) if @b_param.manufacturer_id.blank?
    if @b_param.errors.any?
      render Register::StartForm::Component.new(b_param: @b_param), status: :unprocessable_entity
    elsif @b_param.save
      Email::PartialRegistrationJob.perform_async(@b_param.id)
      redirect_to register_path(b_param_token: @b_param.id_token)
    else
      @b_param.errors.add(:base, translation(:unable_to_save))
      render Register::StartForm::Component.new(b_param: @b_param), status: :unprocessable_entity
    end
  end

  # Everything after the start shares this URL - render the screen matching the
  # registration's progress, or confirm the email when the token is present
  def show
    return confirm if params[:confirmation_token].present? && !@b_param.with_bike?

    if @b_param.with_bike? || (@b_param.details_completed? && !creator_available?)
      render Register::Complete::Component.new(b_param: @b_param, bike: @b_param.created_bike)
    else
      render Register::DetailsForm::Component.new(b_param: @b_param)
    end
  end

  def update
    return redirect_to(register_path(b_param_token: @b_param.id_token)) if @b_param.with_bike?

    @b_param.creator_id ||= current_user&.id
    @b_param.image = params[:bike].delete(:image) if params.dig(:bike, :image).present?
    @b_param.clean_params(update_params.as_json)
    @b_param.save
    if creator_available?
      create_bike_and_redirect
    else
      # Everything is saved on the b_param - the bike is created once the
      # confirmation link from the partial registration email is clicked
      redirect_to register_path(b_param_token: @b_param.id_token)
    end
  end

  private

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
      redirect_to register_path(b_param_token: @b_param.id_token)
    end
  end

  def find_b_param
    @b_param = BParam.find_for_token(params[:b_param_token], user_id: current_user&.id)
    return if @b_param.present?

    flash[:info] = translation(:registration_not_found) if params[:b_param_token].present?
    redirect_to new_register_path
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
    flash[:error] = @b_param.bike_errors&.to_sentence if bike.errors.any?
    redirect_to register_path(b_param_token: @b_param.id_token)
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
    {details_completed: true, bike: bike_params}
  end
end
