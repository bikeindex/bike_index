class OrganizationsController < ApplicationController
  before_action :set_bparam, only: [:embed, :embed_extended]
  skip_before_action :set_x_frame_options_header, only: [:embed, :embed_extended, :embed_create_success]

  def new
    session[:return_to] ||= new_organization_url unless current_user.present?
    @organization = Organization.new
    @active_section = "contact"
  end

  def lightspeed_interface
    if current_user&.organizations&.any?
      redirect_to("https://posintegration.bikeindex.org?organization_id=#{params[:organization_id]}", allow_other_host: true) && return
    end

    session[:return_to] = lightspeed_interface_path
    if current_user.present?
      flash[:info] = translation(:must_create_an_organization_first)
      redirect_to new_organization_path
    else
      flash[:info] = translation(:must_create_an_account_first)
      redirect_to(new_user_path) && return
    end
  end

  def create
    @organization = Organization.new(permitted_create_params)
    if @organization.save
      OrganizationRole.create(user_id: current_user.id, role: "admin", organization_id: @organization.id)
      notify_admins("organization_created")
      flash[:success] = translation(:organization_created)
      if current_user.present?
        redirect_to organization_manage_path(organization_id: @organization.to_param)
      end
    else
      render(action: :new) && return
    end
  end

  # previously accepted stolen_first=true as a parameter.
  # Stopped accepting in PR#1875, because consistency, use stolen=true instead
  def embed
    @bike = BikeCreator.new.build_bike(@b_param)
    @bike.owner_email = params[:email] if params[:email].present?
    @stolen_record = built_stolen_record
    @stolen = @bike.status_stolen?
    render layout: "embed_layout"
  end

  def embed_extended
    @bike = BikeCreator.new.build_bike(@b_param)
    if params[:email].present?
      @bike.owner_email = params[:email]
      @persist_email = true unless defined?(@persist_email)
    end
    render layout: "embed_layout"
  end

  def embed_create_success
    find_organization
    @bike = Bike.find(params[:bike_id])
    render layout: "embed_layout"
  end

  protected

  def set_bparam
    return true unless find_organization.present?
    unless find_organization.auto_user.present?
      flash[:error] = translation(:no_user)
      redirect_to(root_url) && return
    end
    @b_param = if params[:b_param_id_token].present?
      BParam.find_or_new_from_token(params[:b_param_id_token])
    else
      BParam.create(creator_id: @organization.auto_user.id, params: {
        creation_organization_id: @organization.id,
        embeded: true,
        bike: BParam.bike_attrs_from_url_params(params.permit(:status, :stolen).to_h)
      })
    end
  end

  def built_stolen_record
    @bike.stolen_records.last || @bike.build_new_stolen_record(@b_param.stolen_attrs)
  end

  def built_stolen_record_date(str)
    DateTime.strptime("#{str} 06", "%m-%d-%Y %H") if str.present?
  rescue ArgumentError
    Time.current
  end

  def permitted_create_params
    approved_kind = params.dig(:organization, :kind)
    approved_kind = "other" unless Organization.user_creatable_kinds.include?(approved_kind)
    params.require(:organization)
      .permit(:name, :website, locations_attributes: permitted_locations_params)
      .merge(auto_user_id: current_user.id, kind: approved_kind)
  end

  def permitted_locations_params
    %i[name zipcode city state_id country_id street phone publicly_visible]
  end

  def find_organization
    @organization = Organization.friendly_find(params[:id])
    return @organization if @organization.present?
    flash[:error] = translation(:not_found)
    redirect_to(root_url) && return
  end

  def notify_admins(type)
    AdminNotifier.new.for_organization(organization: @organization, user: current_user, type: type)
  end
end
