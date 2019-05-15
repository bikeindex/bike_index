class OrganizationsController < ApplicationController
  before_filter :set_bparam, only: [:embed, :embed_extended]
  skip_before_filter :set_x_frame_options_header, only: [:embed, :embed_extended, :embed_create_success]
  layout "application_revised"

  def new
    session[:return_to] ||= new_organization_url unless current_user.present?
    @organization = Organization.new
    @active_section = "contact"
  end

  def connect_lightspeed
    if current_user && current_user.organizations.any?
      redirect_to "https://posintegration.bikeindex.org" and return
    end

    session[:return_to] = connect_lightspeed_path
    if current_user.present?
      flash[:info] = "You have to create an organization on Bike Index before you can connect with Lightspeed"
      redirect_to new_organization_path
    else
      flash[:info] = "You have to sign up for an account on Bike Index before you can connect with Lightspeed"
      redirect_to new_user_path and return
    end
  end

  def create
    @organization = Organization.new(permitted_create_params)
    if @organization.save
      Membership.create(user_id: current_user.id, role: "admin", organization_id: @organization.id)
      notify_admins("organization_created")
      flash[:success] = "Organization Created successfully!"
      if current_user.present?
        redirect_to organization_manage_index_path(organization_id: @organization.to_param)
      end
    else
      render action: :new and return
    end
  end

  def embed
    @bike = BikeCreator.new(@b_param).new_bike
    @bike.owner_email = params[:email] if params[:email].present?
    @stolen_record = built_stolen_record
    if params[:non_stolen]
      @non_stolen = true
    elsif @bike.stolen || params[:stolen_first]
      @stolen = true
    end
    render layout: "embed_layout"
  end

  def embed_extended
    @bike = BikeCreator.new(@b_param).new_bike
    if params[:email].present?
      @bike.owner_email = params[:email]
      @persist_email = true
    end
    render layout: "embed_layout"
  end

  def embed_create_success
    find_organization
    @bike = Bike.find(params[:bike_id]).decorate
    render layout: "embed_layout"
  end

  protected

  def set_bparam
    return true unless find_organization.present?
    unless find_organization.auto_user.present?
      flash[:error] = "We're sorry, that organization doesn't have a user set up to register bikes through. Email contact@bikeindex.org if this seems like an error."
      redirect_to root_url and return
    end
    if params[:b_param_id_token].present?
      @b_param = BParam.find_or_new_from_token(params[:b_param_id_token])
    else
      hash = {
        creation_organization_id: @organization.id,
        embeded: true,
        bike: { stolen: params[:stolen] },
      }
      @b_param = BParam.create(creator_id: @organization.auto_user.id, params: hash)
    end
  end

  def built_stolen_record
    if @b_param.params && @b_param.params["stolen_record"].present?
      stolen_attrs = @b_param.params["stolen_record"].except("phone_no_show")
    else
      stolen_attrs = { country_id: Country.united_states.id, date_stolen: Time.zone.now }
    end
    @bike.stolen_records.build(stolen_attrs)
  end

  def built_stolen_record_date(str)
    DateTime.strptime("#{str} 06", "%m-%d-%Y %H") if str.present?
  rescue ArgumentError
    Time.zone.now
  end

  def permitted_create_params
    approved_kind = params.dig(:organization, :kind)
    approved_kind = "other" unless Organization.creatable_kinds.include?(approved_kind)
    params.require(:organization)
          .permit(:name, :website)
          .merge(auto_user_id: current_user.id, kind: approved_kind)
  end

  def find_organization
    @organization = Organization.friendly_find(params[:id])
    return @organization if @organization.present?
    flash[:error] = "We're sorry, that organization isn't on Bike Index yet. Email contact@bikeindex.org if this seems like an error."
    redirect_to root_url and return
  end

  def notify_admins(type)
    AdminNotifier.new.for_organization(organization: @organization, user: current_user, type: type)
  end
end
