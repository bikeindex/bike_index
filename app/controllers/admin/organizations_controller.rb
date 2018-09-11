class Admin::OrganizationsController < Admin::BaseController
  before_filter :find_organization, only: [:show, :edit, :update, :destroy]
  before_filter :set_sort_and_direction, only: [:index]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    orgs = Organization.all
    orgs = orgs.paid if params[:is_paid].present?
    orgs = orgs.admin_text_search(params[:query]) if params[:query].present?
    orgs = orgs.where(org_type: params[:org_type]) if params[:org_type].present?
    @organizations = orgs.reorder("#{@sort} #{@sort_direction}").page(page).per(per_page)
    @organizations_count = orgs.count
  end

  def show
    @locations = @organization.locations.decorate
    bikes = Bike.where(creation_organization_id: @organization.id).reorder('created_at desc')
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    @bikes = bikes.page(page).per(per_page)
    @organization = @organization.decorate
  end

  def show_deleted
    @organizations = Organization.only_deleted.all
  end

  def recover
    @organization = Organization.only_deleted.find(params[:id]).recover
    redirect_to admin_organizations_url
  end

  def new
    @organization = Organization.new
  end

  def edit
    @embedable_email = @organization.auto_user.email if @organization.auto_user
  end

  def update
    # Needs to update approved before saving so set_locations_shown is applied on save
    if @organization.update_attributes(permitted_parameters)
      flash[:success] = 'Organization Saved!'
      redirect_to admin_organization_url(@organization)
    else
      render action: :edit
    end
  end

  def create
    @organization = Organization.new(permitted_parameters)
    @organization.approved = true
    if @organization.save
      flash[:success] = 'Organization Created!'
      redirect_to edit_admin_organization_url(@organization)
    else
      render action: :new
    end
  end

  def destroy
    @organization.destroy
    redirect_to admin_organizations_url
  end

  protected

  def permitted_parameters
    params.require(:organization).permit(permitted_organization_params)
  end

  def permitted_organization_params
    (%w(available_invitation_count sent_invitation_count name short_name slug website
       show_on_map is_suspended org_type embedable_user_email auto_user_id lock_show_on_map
       api_access_approved access_token new_bike_notification avatar avatar_cache parent_organization_id
       lightspeed_cloud_api_key use_additional_registration_field approved is_paid show_bulk_import
      ).map(&:to_sym) + [locations_attributes: permitted_locations_params]).freeze
  end

  def set_sort_and_direction
    @sort = params[:sort]
    @sort = 'created_at' unless %w(name created_at approved).include?(@sort)
    @sort_direction = params[:sort_direction]
    @sort_direction = 'desc' unless %w(asc desc).include?(@sort_direction)
  end

  def permitted_locations_params
    %w(name zipcode city state_id _destroy id country_id street phone email shown).map(&:to_sym)
  end

  def find_organization
    @organization = Organization.friendly_find(params[:id])
    unless @organization
      flash[:error] = "Sorry! That organization doesn't exist"
      redirect_to admin_organizations_url and return
    end
  end
end
