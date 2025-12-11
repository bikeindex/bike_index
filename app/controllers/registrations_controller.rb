class RegistrationsController < ApplicationController
  skip_before_action :set_x_frame_options_header, except: [:new]
  skip_before_action :verify_authenticity_token, only: [:create] # Because it was causing issues, and we don't need it here
  before_action :simple_header
  layout "reg_embed"

  def new
    @stolen = params[:stolen] # Passed into embed form
    render layout: "application"
  end

  # Attributes assigned in the partial, but can be overridden so it can be used anywhere
  def embed
    @organization = current_organization
    @owner_email = current_user&.email
    @selectable_child_organizations = find_selectable_child_organizations
    creation_organization_id = @selectable_child_organizations.any? ? nil : @organization&.id
    if params[:button_and_header].present?
      @button_and_header = valid_hex(params[:button_and_header])
    elsif params[:button].present?
      @button = valid_hex(params[:button])
    end
    if @b_param.blank?
      bike_params = {creation_organization_id: creation_organization_id, owner_email: @owner_email}
        .merge(BParam.status_hash_from_params(params))
      @b_param = BParam.new(params: {bike: bike_params.as_json})
    end
    @stolen = @b_param.status_stolen?
    @vehicle_select = !BinxUtils::InputNormalizer.boolean(params[:skip_vehicle_select])
  end

  def create
    @b_param = BParam.new(permitted_params)
    @b_param.errors.add :owner_email, "required" unless @b_param.owner_email.present?
    if @b_param.errors.blank? && @b_param.save
      Email::PartialRegistrationJob.perform_async(@b_param.id)
    else
      @page_errors = @b_param.errors
      render action: :new
    end
  end

  private

  def simple_header
    @simple_header ||= BinxUtils::InputNormalizer.boolean(params[:simple_header])
  end

  def find_selectable_child_organizations
    return [] unless @organization.present? && BinxUtils::InputNormalizer.boolean(params[:select_child_organization])

    @organization.child_organizations
  end

  # returns up to 6 letters/numbers, for safety
  def valid_hex(str)
    "##{str.strip.gsub(/\W/, "")[0..5]}"
  end

  def permitted_params
    params.require(:b_param).permit(:creation_organization_id,
      :cycle_type,
      :manufacturer_id,
      :owner_email,
      :primary_frame_color_id,
      :secondary_frame_color_id,
      :status,
      :tertiary_frame_color_id)
      .merge(
        origin: "embed_partial",
        propulsion_type_motorized: params[:propulsion_type_motorized]
      )
  end
end
