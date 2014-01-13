class Admin::DashboardController < ApplicationController
  before_filter :require_superuser!
  layout "admin"
  def index
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

  def maintenance
    # @bikes here because this is the only one we're using the standard admin bikes table
    @bikes = Bike.unscoped.where(example: true) 
    mnfg_other = Manufacturer.fuzzy_name_find("other")
    @component_mnfgs = Component.where(manufacturer_id: mnfg_other.id)
    @bike_mnfgs = Bike.where(manufacturer_id: mnfg_other.id)
    @component_types = Component.where(Ctype_id: Ctype.find_by_name("Other").id )
    @handlebar_types = Bike.where(handlebar_type_id: HandlebarType.find_by_name("Other style").id )
    @frame_material_types = Bike.where(frame_material_id: FrameMaterial.find_by_name("Other style").id)
    @paint = Paint.where("color_id IS NULL")
  end

end
