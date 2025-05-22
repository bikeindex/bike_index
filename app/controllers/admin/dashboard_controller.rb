class Admin::DashboardController < Admin::BaseController
  around_action :set_reading_role, only: [:index]

  def index
    @period = "week"
    set_period # graphing set up
    @organizations = Organization.unscoped.order("created_at DESC").limit(10)
    bikes = Bike.unscoped.default_includes
      .includes(:creation_organization, :paint, :recovered_records)
    bikes = bikes.not_spam unless current_user.su_option?(:no_hide_spam)
    @bikes = bikes.order(id: :desc).limit(10)
    @users = User.valid_only.includes(organization_roles: [:organization]).limit(5).order(id: :desc)
  end

  def maintenance
    # @bikes here because this is the only one we're using the standard admin bikes table
    @bikes = Bike.unscoped.order("created_at desc").where(example: true).limit(10)
    mnfg_other_id = Manufacturer.other.id
    @component_mnfgs = Component.where(manufacturer_id: mnfg_other_id).reorder(id: :desc).limit(100)
    @bike_mnfgs = Bike.where(manufacturer_id: mnfg_other_id)
    @component_types = Component.where(ctype_id: Ctype.other.id)
    @bikes_other_handlebar_type = Bike.where(handlebar_type: Bike.handlebar_types[:other]).reorder(id: :desc).limit(50)
    @paint = Paint.where("color_id IS NULL")
  end

  def autocomplete_status
    @autocomplete_info = Autocomplete::Loader.info
  end

  def scheduled_jobs
  end

  def crediblity_badges
  end

  def bust_z_cache
    Rails.cache.clear
    flash[:success] = "Z cash WAAAAAS busted!"
    redirect_to admin_root_url
  end

  def destroy_example_bikes
    org = Organization.friendly_find("bikeindex")
    bikes = Bike.unscoped.where(example: true)
    # The example bikes for the API docs on production are created by Bike Index Administrators
    # This way we don't clear them when we clear the rest of the example bikes
    bikes.each { |b| b.destroy unless b.creation_organization_id == org.id }
    flash[:success] = "Example bikes cleared!"
    redirect_to admin_root_url
  end

  def tsvs
    @blocklist = FileCacheMaintainer.blocklist
    @tsvs = FileCacheMaintainer.files
  end

  def update_tsv_blocklist
    new_blocklist = params[:blocklist].split(/\n|\r/).reject { |t| t.blank? }
    FileCacheMaintainer.reset_blocklist_ids(new_blocklist)
    redirect_to admin_tsvs_path
  end

  def ip_location
    @cloudflare_hash = IpAddressParser.location_hash(request)
    @geocoder_hash = IpAddressParser.location_hash_geocoder(forwarded_ip_address, new_attrs: true)
    @headers = request.headers.to_h.select { |k, _v| k.start_with?("HTTP_") }.to_h
  end
end
