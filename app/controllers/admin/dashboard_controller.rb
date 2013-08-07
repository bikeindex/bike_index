class Admin::DashboardController < ApplicationController
  before_filter :require_superuser!
  layout "admin"
  def show
    @bikes = Bike.limit(5).order("created_at desc")
    @users = User.limit(5).order("created_at desc")    
    @flavors = FlavorText.all
    @flavor = FlavorText.new
  end

  def invitations
    @organizations = Organization.all 
    @organization_invitation = OrganizationInvitation.new 
    @bike_token_invitation = BikeTokenInvitation.new 
  end

end
