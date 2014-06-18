class Admin::DashboardController < ApplicationController
  before_filter :require_superuser!
  layout "admin"
  def index
    @bikes = Bike.unscoped.order('created_at desc').limit(10)
    @users = User.limit(5).order("created_at desc")    
    @flavors = FlavorText.all
    @flavor = FlavorText.new
  end

  def invitations
    @organizations = Organization.all 
    @organization_invitation = OrganizationInvitation.new 
    @bike_token_invitation = BikeTokenInvitation.new 
  end

  def maintenance
    # @bikes here because this is the only one we're using the standard admin bikes table
    @bikes = Bike.unscoped.order("created_at desc").where(example: true).limit(10)
    mnfg_other = Manufacturer.fuzzy_name_find("Other")
    @component_mnfgs = Component.where(manufacturer_id: mnfg_other.id)
    @bike_mnfgs = Bike.where(manufacturer_id: mnfg_other.id)
    @component_types = Component.where(ctype_id: Ctype.find_by_name("other").id )
    @handlebar_types = Bike.where(handlebar_type_id: HandlebarType.find_by_slug("other").id )
    @paint = Paint.where("color_id IS NULL")
  end

  def bust_z_cache
    Rails.cache.clear
    flash[:notice] = "Z cash WAAAAAS busted!"
    redirect_to admin_root_url
  end

  def destroy_example_bikes
    org = Organization.find_by_slug('bikeindex')
    bikes = Bike.unscoped.where(example: true)
    # The example bikes for the API docs on production are created by Bike Index Administrators
    # This way we don't clear them when we clear the rest of the example bikes
    bikes.each { |b| b.destroy unless b.creation_organization_id == org.id }
    flash[:notice] = "Example bikes cleared!"
    redirect_to admin_root_url
  end

end
