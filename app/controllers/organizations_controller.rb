class OrganizationsController < ApplicationController
  before_filter :authenticate_user!, only: [:show, :edit, :update, :destroy]
  before_filter :find_organization, except: [:new, :create]
  before_filter :require_membership, only: [:show, :edit, :update, :destroy]
  before_filter :require_admin, only: [:edit, :update, :destroy]
  before_filter :set_bparam, only: [:embed, :embed_extended]
  layout "organization"

  def new
    unless current_user.present?
      @user = User.new
    end
    @organization = Organization.new
    @active_section = "contact"
    render layout: 'content'
  end

  def create
    user = current_user
    @organization = Organization.new(
      name: params[:organization][:name],
      website: params[:organization][:website],
      org_type: params[:organization][:org_type]
    )
    if @organization.save
      membership = Membership.create(user_id: user.id, role: 'admin', organization_id: @organization.id)
      @organization.update_attribute :auto_user_id, user.id

      feedback = Feedback.create(email: current_user.email,
        body: "#{@organization.name} signed up for the Index",
        feedback_hash: { organization_id: @organization.id },
        title: "New Organization created",
        feedback_type: 'organization_created')
      flash[:notice] = "Organization Created successfully!"
      if current_user.present?
        redirect_to organization_url(@organization) and return
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
    bikes = bikes.paginate(page: params[:page]).per_page(100)
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
      websitey = params[:organization][:website]
      if Urlifyer.urlify(websitey)
        @organization.website = websitey
        if @organization.save
          # raise "organization saved"
          redirect_to edit_organization_url(@organization), notice: "Organization updated"
        else
          raise "organization not saved"
          render action: :settings
        end
      else
        flash[:error] = "We're sorry, that didn't look like a valid url to us!"
        render action: :settings
      end
    end
  end

  def destroy
    @organization.destroy
    redirect_to root_url
  end

  protected

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
    @organization = Organization.find_by_slug(params[:id])
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

end
