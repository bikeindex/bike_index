class OrganizationsController < ApplicationController
  before_filter :authenticate_user!, only: [:show, :edit, :update, :destroy]
  before_filter :find_organization
  before_filter :require_membership, only: [:show, :edit, :update, :destroy]
  before_filter :require_admin, only: [:edit, :update, :destroy]
  layout "organization"
  
  def edit
    @bikes = Bike.where(creation_organization_id: @organization.id).order("created_at asc")
    # @bikes = bikes.decorate
  end

  def show
    bikes = Bike.where(creation_organization_id: @organization.id).order("created_at asc")
    @bikes = bikes.decorate
  end

  def embed
    b_param = BParam.create(creator_id: @organization.auto_user.id, params: {creation_organization_id: @organization.id, embeded: true})
    @bike = BikeCreator.new(b_param).new_bike
    @bike.owner_email = params[:email] if params[:email].present?
    if params[:sf_safe].present?
      render action: :embed_sf_safe, layout: 'embed_layout'
    else
      render layout: 'embed_layout'
    end
  end

  def embed_extended
    b_param = BParam.create(creator_id: @organization.auto_user.id, params: {creation_organization_id: @organization.id, embeded: true})
    @bike = BikeCreator.new(b_param).new_bike
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

  def destroy
    @organization.destroy
    redirect_to root_url
  end

  protected

  def find_organization 
    @organization = Organization.find_by_slug(params[:id]).decorate
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
