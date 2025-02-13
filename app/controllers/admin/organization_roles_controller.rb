class Admin::OrganizationRolesController < Admin::BaseController
  include SortableTable
  before_action :set_period, only: %i[index]
  before_action :find_organization_role, only: %i[show edit update destroy]
  before_action :find_organizations, except: %i[index destroy]

  def index
    @per_page = params[:per_page] || 50
    @pagy, @collection = pagy(
      matching_organization_roles.includes(:user, :sender, :organization).reorder("organization_roles.#{sort_column} #{sort_direction}"),
      limit: @per_page
    )
  end

  def show
    redirect_to edit_admin_organization_role_path
  end

  def new
    @organization_role = OrganizationRole.new(organization_id: current_organization&.id)
  end

  def edit
  end

  def update
    if @organization_role.update(permitted_parameters)
      flash[:success] = "Organization Role Saved!"
      redirect_to admin_organization_role_url(@organization_role)
    else
      render action: :edit
    end
  end

  def create
    @organization_role = OrganizationRole.new(permitted_parameters.merge(sender: current_user))
    if @organization_role.save
      flash[:success] = "Organization Role Created!"
      redirect_to admin_organization_role_url(@organization_role)
    else
      render action: :new
    end
  end

  def destroy
    @organization_role.destroy
    flash[:success] = "Organization Role deleted successfully"
    redirect_to admin_organization_roles_url
  end

  helper_method :matching_organization_roles

  protected

  def sortable_columns
    %w[created_at invited_email sender_id claimed_at organization_id role deleted_at]
  end

  def permitted_parameters
    params.require(:organization_role).permit(:organization_id, :user_id, :role, :invited_email)
  end

  def find_organization_role
    @organization_role = OrganizationRole.unscoped.find(params[:id])
  end

  def find_organizations
    @organizations = Organization.all
  end

  def matching_organization_roles
    organization_roles = if current_organization.present?
      current_organization.organization_roles
    else
      OrganizationRole.all
    end
    @deleted_organization_roles = current_organization&.deleted? || InputNormalizer.boolean(params[:search_deleted])
    organization_roles = organization_roles.deleted if @deleted_organization_roles

    @time_range_column = sort_column if %w[claimed_at deleted_at].include?(sort_column)
    @time_range_column ||= "created_at"
    organization_roles.where(@time_range_column => @time_range)
  end
end
