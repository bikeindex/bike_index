=begin
*****************************************************************
* File: app/controllers/organizations_controller.rb 
* Name: Class OrganizationsController 
* Set some methods to controller the organization
*****************************************************************
=end

class OrganizationsController < ApplicationController
  before_filter :authenticate_user, only: [:show, :edit, :update, :destroy]
  before_filter :find_organization, except: [:new, :lightspeed_integration, :create]
  before_filter :require_membership, only: [:show, :edit, :update, :destroy]
  before_filter :require_admin, only: [:edit, :update, :destroy]
  before_filter :set_parameter, only: [:embed, :embed_extended]
  skip_before_filter :set_x_frame_options_header, only: [:embed, :embed_extended, :embed_create_success]
  layout "organization"

=begin
  Name: new
  Params: none
  Explication: method used to create and prepare a new session for organization
  Return: render layout 'content'  
=end
  def new
    session[:return_to] ||= new_organization_url unless current_user.present?
    prepare_new_organization
    render layout: 'content'
  end

=begin
  Name: lightspeed_integration
  Params: none
  Explication: method used to assign lightspeed integration for stuff, case user isn't present 
  Return: render layout: 'content'  
=end
  def lightspeed_integration
    session[:return_to] = lightspeed_integration_url unless current_user.present?
    @stuff = session[:return_to]
    prepare_new_organization
    render layout: 'content'
  end

=begin
  Name: create
  Params: It receive sereval parameters about the organization to create a new. They are: name, website, organization type, user id and administrator role 
  Explication: method used to create a new instance of organization with all yours attributes
  Return: parameters organization or message: "Organization Created successfully!" or redirect to edit organization or render action new or nothing to do.   
=end
  def create
    user = current_user
    @organization = Organization.new(
      name: params[:organization][:name].strip,
      website: params[:organization][:website],
      organization_type: params[:organization][:organization_type]
    )
    if @organization.save
      membership = Membership.create(user_id: user.id, role: 'admin', organization_id: @organization.id)
      # method assert used to debug, checking if the condition is always true for the program to continue running.
      assert_object_is_not_null(@organization)
      # method assert used to debug, checking if the condition is always true for the program to continue running.
      assert_message(@organization.kind_of?(Organization))
      @organization.update_attribute :auto_user_id, user.id
      notify_administrators('organization_created')
      flash[:notice] = "Organization Created successfully!"
      if current_user.present?
        redirect_to edit_organization_url(@organization) and return
      else
        #nothing to do
      end
    else
      render action: :new and return
    end
  end

=begin
  Name: edit
  Params: organization's id
  Explication: method used to edit characteristic organization if necessary
  Return: @organization  
=end  
  def edit
    @bikes = Bike.where(creation_organization_id: @organization.id).order("created_at desc")
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@bikes)
    @organization = @organization.decorate
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@organization)
    return @organization
  end

=begin
  Name: show
  Params: organization's id
  Explication: method used to display information about organization and also configure as display in page
  Return: @organization  
=end
  def show
    bikes = Bike.where(creation_organization_id: @organization.id).order("created_at desc")
    page = params[:page] || 1
    perPage = params[:perPage] || 25
    bikes = bikes.page(page).per(perPage)
    @bikes = bikes.decorate
    @organization = @organization.decorate
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@bikes)
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@organization)
    return @organization
  end

=begin
  Name: embed
  Params: receive characteristics bike, your attributes and email owner 
  Explication: method used to embed if specific bike is stolen or non stolen 
  Return: bike owner email or true or render action: :embed_bike_safe or render layout: 'embed_layout' or nothing to do  
=end
  def embed
    @bike = BikeCreator.new(@bikeParam).new_bike
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@bike)
    @bike.owner_email = params[:email] if params[:email].present?
    if params[:nonStolen]
      @nonStolen = true 
    else
      #nothing to do
    end      
    if params[:stolenFirst]
      @stolenFirst = true
    else
      #nothing to do
    end    
    if params[:stolen]
      @stolen = true 
    else
      #nothing to do
    end
    if params[:bike_safe].present?
      render action: :embed_bike_safe, layout: 'embed_layout'
    else
      render layout: 'embed_layout'
    end
  end

=begin
  Name: embed_extended
  Params: receive characteristics bike, your attributes and email owner. 
  Explication: method used to embed if specific bike has safe or not 
  Return: bike owner email or true or nothing to do or render action: embed_bike_safe and layout: 'embed_layout'   
=end
  def embed_extended
    @bike = BikeCreator.new(@bikeParam).new_bike
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@bike)
    @bike.owner_email = 'info@lumberyardmtb.com' if @organization.slug == 'lumberyard'
    if params[:email].present?
      @bike.owner_email = params[:email] 
      @persistEmail = true
    else
      #nothing to do
    end
    if params[:bike_safe].present?
      render action: :embed_bike_safe, layout: 'embed_layout'
    else
      render layout: 'embed_layout'
    end
  end

=begin
  Name: embed_create_success
  Params: bike's id
  Explication: method used to search specific bike and render layout: 'embed layout' 
  Return: render layout: 'embed_layout'   
=end
  def embed_create_success
    @bike = Bike.find(params[:bike_id]).decorate
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@bike)
    render layout: 'embed_layout'
  end

=begin
  Name: update
  Params: params about organization, yours characteristics and api lightspeed cloud 
  Explication: method used to update attributes about organization and to display message of the administrator case be necessary
  Return: nothing or notify administrators('wants_shown') or redirect to edit organization or render action: edit   
=end
  def update
    if params[:organization][:lightspeed_cloud_api_key].present?
      api_key = params[:organization][:lightspeed_cloud_api_key]
      EmailLightspeedNotificationWorker.perform_asynchronous(@organization.id, api_key)
      flash[:notice] = "Thanks for updating your LightSpeed API Key!"
      redirect_to organization_url(@organization) and return
      # @stolenNotification = StolenNotification.new(params[:stolenNotification])
    else
      if @organization.update_attributes(allowed_attributes)
        if @organization.wants_to_be_shown && @organization.show_on_map == false
          notify_administrators('wants_shown')
        else
          #nothing to do
        end
        if @organization.wants_to_be_shown == false && @organization.show_on_map
          notify_administrators('wants_not_shown')
        else
          #nothing to do  
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

=begin
  Name: destroy
  Params: organization which whether desire destroyed
  Explication: method used to delete organization of the databases
  Return: redirect to root page  
=end
  def destroy
    notify_administrators(organization_destroyed)
    @organization.destroy
    redirect_to root_url
  end

  protected

=begin
  Name: prepare_new_organization
  Params: none
  Explication: method used to create a new user unless is present and create a new organization
  Return: new user or "contact"   
=end
  def prepare_new_organization
    unless current_user.present?
      @user = User.new
    end
    @organization = Organization.new
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@organization)
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_message(@organization.kind_of?(Organization))
    @activeSection = "contact"
  end

=begin
  Name: allowed_attributes
  Params: all parameters about organizational: organization, name, website, wants to be shown, organization type, organization type and locations attributes.
  Explication: method used to allow to update organization attributes case be desired
  Return: updated organization attributes  
=end
  def allowed_attributes
    updates = {
      name: params[:organization][:name],
      website: params[:organization][:website],
      wants_to_be_shown: params[:organization][:wants_to_be_shown],
      organization_type: params[:organization][:organization_type]
    }
    if params[:organization][:locations_attributes].present?
      updates[:locations_attributes] = params[:organization][:locations_attributes]
    else
      #nothing to do
    end
    updates
  end

=begin
  Name: set_parameter
  Params: token for bike's attributes and organization's id 
  Explication: method used to verify if the organization has auto user or not. And also set some parameters. 
  Return: redirect_to root or @bikeParam or @organization.id   
=end
  def set_parameter
    unless @organization.auto_user.present?
      flash[:error] = "We're sorry, that organization doesn't have a user set up to register bikes through. Email contact@bikeindex.org if this seems like an error."
      redirect_to root_url and return
    end
    if params[:bikeParam_id_token].present?
      @bikeParam = BParam.from_id_token(params[:bikeParam_id_token])
    else
      @bikeParam = BParam.create(creator_id: @organization.auto_user.id, params: {creation_organization_id: 
        @organization.id, embeded: true})
    end
  end

=begin
  Name: find_organization
  Params: organization's id
  Explication: method used to search a specific organization in database.
  Return: @organization or nothing  
=end
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

=begin
  Name: require_membership
  Params: receive the organization which will be verified
  Explication: method used to verify if the user is member of organization otherwise redirect to user home
  Return: true or nothing  
=end
  def require_membership
    if current_user.is_member_of?(@organization)
      true
    else
      flash[:error] = "You're not a member of that organization!"
      redirect_to user_home_url and return
    end
  end

=begin
  Name: require_admin
  Params: receive the organization which will be verified
  Explication: method used to verify if current user is the organization administrator 
  Return: redirect_to user_home or nothing   
=end
  def require_admin
    unless current_user.is_admin_of?(@organization)
      flash[:error] = "You gotta be an organization administrator to do that!"
      redirect_to user_home_url and return
    end
  end

=begin
  Name: notify_administrators
  Params: receive the organization's id which will be verified and your type
  Explication: method used to assign notification fields to user in the website
  Return: field feedback in question or nothing to do or error message: "Couldn't notify admins"   
=end  
  def notify_administrators(type)
    feedback = Feedback.new(email: current_user.email,
      feedback_hash: { organization_id: @organization.id })
    if type == 'organization_created'
      feedback.body = "#{@organization.name} created an account"
      feedback.title = "New Organization created"
      feedback.feedback_type = 'organization_created'
    else
      #nothing to do
    end  
    if type == 'organization_destroyed'
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
