class RegisterController < ApplicationController
  before_action :find_b_param, only: %i[details update complete]

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
      redirect_to register_details_path(b_param_token: @b_param.id_token)
    else
      @b_param.errors.add(:base, translation(:unable_to_save))
      render :new, status: :unprocessable_entity
    end
  end

  def details
  end

  def update
    @b_param.creator_id ||= current_user&.id
    # clean_params runs before_save, resolving the merged foreign keys
    @b_param.params = @b_param.params.with_indifferent_access.deep_merge(update_params.as_json)
    @b_param.save
    if creator_available?
      create_bike_and_redirect
    else
      # Without a user to assign the bike to, everything is saved on the b_param -
      # the confirmation email finishes the registration (and creates the account)
      redirect_to register_complete_path(b_param_token: @b_param.id_token)
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
      redirect_to(register_path) && return
    end
    if @b_param.with_bike? && action_name != "complete"
      redirect_to register_complete_path(b_param_token: @b_param.id_token)
    end
  end

  def creator_available?
    @b_param.creator_id.present? || @b_param.creation_organization&.auto_user_id.present?
  end

  def create_bike_and_redirect
    bike = BikeServices::Creator.new(ip_address: forwarded_ip_address).create_bike(@b_param)
    if bike.errors.any?
      flash[:error] = @b_param.bike_errors&.to_sentence
      redirect_to register_details_path(b_param_token: @b_param.id_token)
    else
      redirect_to register_complete_path(b_param_token: @b_param.id_token)
    end
  end

  def create_params
    bike_params = params.require(:b_param).permit(:manufacturer_id, :frame_model, :owner_email)
      .to_h.merge(BParam.status_hash_from_params(params))
    bike_params[:creation_organization_id] = current_organization.id if current_organization.present?
    {bike: bike_params, propulsion_type_motorized: params[:propulsion_type_motorized]}
  end

  def update_params
    {bike: params.fetch(:bike, {}).permit(:primary_frame_color_id, :secondary_frame_color_id,
      :tertiary_frame_color_id, :serial_number, :frame_size, :frame_size_number, :frame_size_unit,
      :bike_sticker, :phone, :status, :frame_model).reject { |_k, v| v.blank? }}
  end
end
