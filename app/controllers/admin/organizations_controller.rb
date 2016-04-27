class Admin::OrganizationsController < Admin::BaseController
  before_filter :find_organization, only: [:show, :edit, :update, :destroy]

  def index
    @organizations = Organization.all
    @bikes = Bike
  end

  def show
    @locations = @organization.locations.decorate
    bikes = Bike.where(creation_organization_id: @organization.id).order("created_at desc")
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    bikes = bikes.page(page).per(per_page)
    @bikes = bikes.decorate
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
    @organization.update_attribute :approved, params[:organization][:approved]
    if @organization.update_attributes(params[:organization])
      flash[:notice] = "Organization Saved!"
      redirect_to admin_organization_url(@organization)
    else
      render action: :edit
    end
  end

  def create
    @organization = Organization.new(params[:organization])
    @organization.approved = true
    if @organization.save
      flash[:notice] = "Organization Created!"
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

  def find_organization
    @organization = Organization.find_by_slug(params[:id])
    unless @organization
      flash[:error] = "Sorry! That organization doesn't exist"
      redirect_to admin_organizations_url and return
    end
  end
end
