class Admin::OrganizationsController < Admin::BaseController
  include SortableTable
  before_filter :find_organization, only: [:show, :edit, :update, :destroy]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    orgs = Organization.all
    orgs = orgs.paid if params[:is_paid].present?
    orgs = orgs.admin_text_search(params[:query]) if params[:query].present?
    orgs = orgs.where(kind: kind_for_organizations) if params[:kind].present?
    @organizations_count = orgs.count
    @organizations = orgs.reorder(sort_column + " " + sort_direction).page(page).per(per_page)
    render layout: "new_admin"
  end

  def show
    @locations = @organization.locations.decorate
    bikes = Bike.where(creation_organization_id: @organization.id).reorder('created_at desc')
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    @bikes = bikes.page(page).per(per_page)
    @organization = @organization.decorate
    render layout: "new_admin"
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
    approved_kind = params.dig(:organization, :kind)
    approved_kind = "other" unless Organization.kinds.include?(approved_kind)
    params.require(:organization)
          .permit(:available_invitation_count, :sent_invitation_count, :name, :short_name, :slug, :website,
                  :ascend_name, :show_on_map, :is_suspended, :embedable_user_email, :auto_user_id, :lock_show_on_map,
                  :api_access_approved, :access_token, :new_bike_notification, :avatar, :avatar_cache,
                  :parent_organization_id, :lightspeed_cloud_api_key, :approved,
                  [locations_attributes: permitted_locations_params])
          .merge(kind: approved_kind)
  end

  def sortable_columns
    %w[name approved created_at]
  end

  def kind_for_organizations
    # Legacy enum issue so excited for TODO: Rails 5 update
    Organization::KIND_ENUM[params[:kind].to_sym] || 0
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
