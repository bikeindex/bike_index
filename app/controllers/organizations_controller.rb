class OrganizationsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :require_member!
  before_filter :require_admin!, only: [:edit, :update, :manage, :settings, :destroy]
  before_filter :find_organization
  
  layout "organization"
  
  def show
    @title = @organization.name
    @bikes = Bike.where(creation_organization_id: @organization.id).order("created_at asc")
  end

  def manage
    @title = "Manage #{@organization.name}"
    @bikes = Bike.where(creation_organization_id: @organization.id).non_token.order("created_at asc")
  end

  def settings
    @title = "Settings for #{@organization.name}"
  end

  def update
    websitey = params[:organization][:website]
    if Urlifyer.urlify(websitey)
      @organization.website = websitey
      if @organization.save
        # raise "organization saved"
        redirect_to settings_url(:subdomain => @organization.slug), notice: "Organization updated"
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
    redirect_to root_url(:subdomain => @organization.slug)
  end

  protected

  def find_organization 
    @organization = current_organization
  end

end
