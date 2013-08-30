class OrganizationsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :find_organization
  before_filter :require_membership
  before_filter :require_admin, only: [:edit, :update, :destroy]
  layout "organization"
  
  def edit
    @title = "Manage #{@organization.name}"
    bikes = Bike.where(creation_organization_id: @organization.id).non_token.order("created_at asc")
    @bikes = bikes.decorate
  end

  def show
    @title = "#{@organization.name}"
    bikes = Bike.where(creation_organization_id: @organization.id).non_token.order("created_at asc")
    @bikes = bikes.decorate
  end

  def update
    websitey = params[:organization][:website]
    if Urlifyer.urlify(websitey)
      @organization.website = websitey
      if @organization.save
        # raise "organization saved"
        redirect_to edit_organizations_url, notice: "Organization updated"
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
    @organization = Organization.find_by_slug(params[:id])
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
