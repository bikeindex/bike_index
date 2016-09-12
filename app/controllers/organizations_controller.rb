class OrganizationsController < ApplicationController
  before_filter :set_bparam, only: [:embed, :embed_extended]
  skip_before_filter :set_x_frame_options_header, only: [:embed, :embed_extended, :embed_create_success]
  layout 'application_revised'

  def new
    session[:return_to] ||= new_organization_url unless current_user.present?
    prep_new_organization
  end

  def lightspeed_integration
    session[:return_to] = lightspeed_integration_url unless current_user.present?
    @stuff = session[:return_to]
    prep_new_organization
  end

  def create
    user = current_user
    @organization = Organization.new(
      name: params[:organization][:name].strip,
      website: params[:organization][:website],
      org_type: params[:organization][:org_type]
    )
    if @organization.save
      membership = Membership.create(user_id: user.id, role: 'admin', organization_id: @organization.id)
      @organization.update_attribute :auto_user_id, user.id
      notify_admins('organization_created')
      flash[:success] = 'Organization Created successfully!'
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
    if params[:sf_safe].present?
      render action: :embed_sf_safe, layout: 'embed_layout'
    else
      render layout: 'embed_layout'
    end
  end

  def embed_extended
    @bike = BikeCreator.new(@b_param).new_bike
    @bike.owner_email = 'info@lumberyardmtb.com' if @organization.slug == 'lumberyard'
    if params[:email].present?
      @bike.owner_email = params[:email]
      @persist_email = true
    end
    if params[:sf_safe].present?
      render action: :embed_sf_safe, layout: 'embed_layout'
    else
      render layout: 'embed_layout'
    end
  end

  def embed_create_success
    find_organization
    @bike = Bike.find(params[:bike_id]).decorate
    render layout: 'embed_layout'
  end

  protected

  def prep_new_organization
    unless current_user.present?
      @user = User.new
    end
    @organization = Organization.new
    @active_section = "contact"
  end

  def set_bparam
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
        bike: { stolen: params[:stolen] }
      }
      @b_param = BParam.create(creator_id: @organization.auto_user.id, params: hash)
    end
  end

  def built_stolen_record
    if @b_param.params && @b_param.params['stolen_record'].present?
      stolen_attrs = @b_param.params['stolen_record'].except('phone_no_show', 'date_stolen_input')
      date_stolen = built_stolen_record_date(@b_param.params['stolen_record']['date_stolen_input'])
      stolen_attrs.merge!(date_stolen: date_stolen)
    else
      stolen_attrs = { country_id: Country.united_states.id, date_stolen: Time.zone.now }
    end
    @bike.stolen_records.build(stolen_attrs)
  end

  def built_stolen_record_date(str)
    DateTime.strptime("#{str} 06", '%m-%d-%Y %H') if str.present?
    rescue ArgumentError
    Time.zone.now
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
