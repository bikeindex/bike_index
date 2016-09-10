class Admin::DashboardController < Admin::BaseController
  def index
    @bikes = Bike.unscoped.includes(:creation_organization, :cycle_type, :manufacturer, :paint).order('created_at desc').limit(10)
    @users = User.includes(:memberships => [:organization]).limit(5).order("created_at desc")
    @flavors = FlavorText.all
    @flavor = FlavorText.new
    @duplicate_groups = DuplicateBikeGroup.unignored.order('created_at desc').limit(5)
  end

  def invitations
    @organizations = Organization.all 
    @organization_invitation = OrganizationInvitation.new 
  end

  def maintenance
    # @bikes here because this is the only one we're using the standard admin bikes table
    @bikes = Bike.unscoped.order('created_at desc').where(example: true).limit(10)
    mnfg_other_id = Manufacturer.other.id
    @component_mnfgs = Component.where(manufacturer_id: mnfg_other_id)
    @bike_mnfgs = Bike.where(manufacturer_id: mnfg_other_id)
    @component_types = Component.where(ctype_id: Ctype.other.id)
    @handlebar_types = Bike.where(handlebar_type_id: HandlebarType.other.id)
    @paint = Paint.where('color_id IS NULL')
  end

  def bust_z_cache
    Rails.cache.clear
    flash[:success] = 'Z cash WAAAAAS busted!'
    redirect_to admin_root_url
  end

  def destroy_example_bikes
    org = Organization.friendly_find('bikeindex')
    bikes = Bike.unscoped.where(example: true)
    # The example bikes for the API docs on production are created by Bike Index Administrators
    # This way we don't clear them when we clear the rest of the example bikes
    bikes.each { |b| b.destroy unless b.creation_organization_id == org.id }
    flash[:success] = "Example bikes cleared!"
    redirect_to admin_root_url
  end

  def tsvs
    @blacklist = FileCacheMaintainer.blacklist
    @tsvs = FileCacheMaintainer.files
  end

  def update_tsv_blacklist
    new_blacklist = params[:blacklist].split(/\n|\r/).reject{|t| t.blank?}
    FileCacheMaintainer.reset_blacklist_ids(new_blacklist)
    redirect_to admin_tsvs_path
  end

end
