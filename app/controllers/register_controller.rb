class RegisterController < ApplicationController
  before_action :find_b_param, only: %i[details update confirm complete]

  def new
    @b_param ||= BParam.new(params: {bike: BParam.status_hash_from_params(params)}.as_json)
  end

  def create
    @b_param = BParam.new(origin: "registration_flow", creator_id: current_user&.id,
      params: create_params.as_json)
    if @b_param.owner_email.blank?
      @b_param.errors.add(:owner_email, translation(:email_required))
      render :new, status: :unprocessable_entity
    elsif @b_param.save
      Email::PartialRegistrationJob.perform_async(@b_param.id)
      redirect_to details_register_path(b_param_token: @b_param.id_token)
    else
      @b_param.errors.add(:base, translation(:unable_to_save))
      render :new, status: :unprocessable_entity
    end
  end

  def details
  end

  def update
    @b_param.creator_id ||= current_user&.id
    @b_param.image = params[:bike].delete(:image) if params.dig(:bike, :image).present?
    # clean_params runs before_save, resolving the merged foreign keys
    @b_param.params = @b_param.params.with_indifferent_access.deep_merge(update_params.as_json)
    @b_param.save
    if creator_available?
      create_bike_and_redirect
    else
      # Everything is saved on the b_param - the bike is created once the
      # confirmation link from the partial registration email is clicked
      redirect_to complete_register_path(b_param_token: @b_param.id_token)
    end
  end

  # The tokenized link from the partial registration email - proves control of the email
  def confirm
    unless @b_param.confirmation_token_matches?(params[:confirmation_token])
      flash[:error] = translation(:invalid_confirmation_link)
      redirect_to(new_register_path) && return
    end
    @b_param.confirm_email!
    if @b_param.details_completed?
      create_bike_and_redirect
    else
      flash[:success] = translation(:email_confirmed_add_details)
      redirect_to details_register_path(b_param_token: @b_param.id_token)
    end
  end

  def complete
    @bike = @b_param.created_bike
  end

  private

  def find_b_param
    @b_param = BParam.find_for_token(params[:b_param_token], user_id: current_user&.id)
    if @b_param.blank?
      flash[:info] = translation(:registration_not_found)
      redirect_to(new_register_path) && return
    end
    if @b_param.with_bike? && action_name != "complete"
      redirect_to complete_register_path(b_param_token: @b_param.id_token)
    end
  end

  def creator_available?
    @b_param.creator_id.present? || @b_param.creation_organization&.auto_user_id.present? ||
      (@b_param.email_confirmed? && confirmed_email_creator.present?)
  end

  # With the email confirmed, the registrant's own account (if the email has one)
  # or the AUTO_ORG_MEMBER system user can stand in as the creator
  def confirmed_email_creator
    return @confirmed_email_creator if defined?(@confirmed_email_creator)

    @confirmed_email_creator = User.fuzzy_email_find(@b_param.owner_email) ||
      User.fuzzy_email_find(ENV["AUTO_ORG_MEMBER"])
  end

  def create_bike_and_redirect
    @b_param.creator_id ||= confirmed_email_creator&.id if @b_param.email_confirmed?
    bike = BikeServices::Creator.new(ip_address: forwarded_ip_address).create_bike(@b_param)
    if bike.errors.any?
      flash[:error] = @b_param.bike_errors&.to_sentence
      redirect_to details_register_path(b_param_token: @b_param.id_token)
    else
      redirect_to complete_register_path(b_param_token: @b_param.id_token)
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
    bike_params["serial_number"] = "unknown" if Binxtils::InputNormalizer.boolean(params[:serial_missing])
    {details_completed: true, bike: bike_params}
  end
end
