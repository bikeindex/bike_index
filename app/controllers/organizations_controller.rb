class OrganizationsController < ApplicationController
  before_filter :authenticate_user!, only: [:show, :edit, :update, :destroy]
  before_filter :find_organization, except: [:new, :lightspeed_integration, :create]
  before_filter :require_membership, only: [:show, :edit, :update, :destroy]
  before_filter :require_admin, only: [:edit, :update, :destroy]
  before_filter :set_bparam, only: [:embed, :embed_extended]
  skip_before_filter :set_x_frame_options_header, only: [:embed, :embed_extended]
  layout "organization"

  def new
    session[:return_to] = new_organization_url unless current_user.present?
    prep_new_organization
    render layout: 'content'
  end

  def lightspeed_integration
    session[:return_to] = lightspeed_integration_url unless current_user.present?
    @stuff = session[:return_to]
    prep_new_organization
    render layout: 'content'
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
      flash[:notice] = "Organization Created successfully!"
      if current_user.present?
        redirect_to edit_organization_url(@organization) and return
      end
    else
      render action: :new and return
    end
  end
  
  def edit
    @bikes = Bike.where(creation_organization_id: @organization.id).order("created_at desc")
    @organization = @organization.decorate
  end

  def show
    bikes = Bike.where(creation_organization_id: @organization.id).order("created_at desc")
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    bikes = bikes.page(page).per(per_page)
    @bikes = bikes.decorate
    @organization = @organization.decorate
  end

  def embed
    @bike = BikeCreator.new(@b_param).new_bike
    @bike.owner_email = params[:email] if params[:email].present?
    if params[:non_stolen]
      @non_stolen = true 
    elsif params[:stolen_first]
      @stolen_first = true
    elsif params[:stolen]
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
    @bike.owner_email = params[:email] if params[:email].present?
    if params[:sf_safe].present?
      render action: :embed_sf_safe, layout: 'embed_layout'
    else
      render layout: 'embed_layout'
    end
  end

  def embed_create_success
    @bike = Bike.find(params[:bike_id]).decorate
    render layout: 'embed_layout'
  end

  def update
    if params[:organization][:lightspeed_cloud_api_key].present?
      api_key = params[:organization][:lightspeed_cloud_api_key]
      EmailLightspeedNotificationWorker.perform_async(@organization.id, api_key)
      flash[:notice] = "Thanks for updating your LightSpeed API Key!"
      redirect_to organization_url(@organization) and return
      # @stolen_notification = StolenNotification.new(params[:stolen_notification])
    else
      if @organization.update_attributes(allowed_attributes)
        if @organization.wants_to_be_shown && @organization.show_on_map == false
          notify_admins('wants_shown')
        elsif @organization.wants_to_be_shown == false && @organization.show_on_map
          notify_admins('wants_not_shown')
        end
        # if Urlifyer.urlify(params[:organization][:website])
        #   @organization.website = websitey
        #   if @organization.save
        redirect_to edit_organization_url(@organization), notice: "Organization updated"
      else
        flash[:error] = "We're sorry, we had trouble updating your organization"
        render action: :edit
      end
    end
  end

  def destroy
    notify_admins(organization_destroyed)
    @organization.destroy
    redirect_to root_url
  end

  protected

  def prep_new_organization
    unless current_user.present?
      @user = User.new
    end
    @organization = Organization.new
    @active_section = "contact"
  end

  def allowed_attributes
    updates = {
      name: params[:organization][:name],
      website: params[:organization][:website],
      wants_to_be_shown: params[:organization][:wants_to_be_shown],
      org_type: params[:organization][:org_type]
    }
    if params[:organization][:locations_attributes].present?
      updates[:locations_attributes] = params[:organization][:locations_attributes]
    end
    updates
  end

  def set_bparam
    unless @organization.auto_user.present?
      flash[:error] = "We're sorry, that organization doesn't have a user set up to register bikes through. Email contact@bikeindex.org if this seems like an error."
      redirect_to root_url and return
    end
    if params[:b_param_id].present?
      @b_param = BParam.find(params[:b_param_id])
    else
      @b_param = BParam.create(creator_id: @organization.auto_user.id, params: {creation_organization_id: @organization.id, embeded: true})
    end
  end

  def find_organization
    if params[:id].match(/\A\d*\z/).present?
      @organization = Organization.find(params[:id])
    else
      @organization = Organization.find_by_slug(params[:id])
    end
    unless @organization.present?
      flash[:error] = "We're sorry, that organization isn't on Bike Index yet. Email contact@bikeindex.org if this seems like an error."
      redirect_to root_url and return
    end
  end

  def require_membership
    if current_user.is_member_of?(@organization)
      true
    else
      flash[:error] = "You're not a member of that organization!"
      redirect_to user_home_url and return
    end
  end

  def require_admin
    unless current_user.is_admin_of?(@organization)
      flash[:error] = "You gotta be an organization administrator to do that!"
      redirect_to user_home_url and return
    end
  end
  
  def notify_admins(type)
    feedback = Feedback.new(email: current_user.email,
      feedback_hash: { organization_id: @organization.id })
    if type == 'organization_created'
      feedback.body = "#{@organization.name} created an account"
      feedback.title = "New Organization created"
      feedback.feedback_type = 'organization_created'
    elsif type == 'organization_destroyed'
      feedback.body = "#{@organization.name} deleted their account"
      feedback.title = "Organization deleted themselves"   
      feedback.feedback_type = 'organization_destroyed'
    else
      feedback.feedback_type = 'organization_map'
      if type == 'wants_shown'
        feedback.body = "#{@organization.name} wants to be shown"
        feedback.title = "Organization wants to be shown"   
      else
        feedback.body = "#{@organization.name} wants to NOT be shown"
        feedback.title = "Organization wants OFF map"  
      end
    end
    raise StandardError, "Couldn't notify admins" unless feedback.save
  end

end
