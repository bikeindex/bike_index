class Admin::OrganizationRolesController < Admin::BaseController
  include SortableTable
  before_action :find_membership, only: [:show, :edit, :update, :destroy]
  before_action :find_organizations

  def index
    @per_page = params[:per_page] || 50
    @pagy, @organization_roles = pagy(
      matching_organization_roles.includes(:user, :sender, :organization).reorder("organization_roles.#{sort_column} #{sort_direction}"),
      limit: @per_page
    )
  end

  def show
    redirect_to edit_admin_membership_path
  end

  def new
    @membership = OrganizationRole.new(organization_id: current_organization&.id)
  end

  def edit
  end

  def update
    if @membership.update(permitted_parameters)
      flash[:success] = "OrganizationRole Saved!"
      redirect_to admin_membership_url(@membership)
    else
      render action: :edit
    end
  end

  def create
    @membership = OrganizationRole.new(permitted_parameters.merge(sender: current_user))
    if @membership.save
      flash[:success] = "OrganizationRole Created!"
      redirect_to admin_membership_url(@membership)
    else
      render action: :new
    end
  end

  def destroy
    @membership.destroy
    flash[:success] = "membership deleted successfully"
    redirect_to admin_organization_roles_url
  end

  protected

  def sortable_columns
    %w[created_at invited_email sender_id claimed_at organization_id role deleted_at]
  end

  def permitted_parameters
    params.require(:organization_role).permit(:organization_id, :user_id, :role, :invited_email)
  end

  def find_membership
    @membership = OrganizationRole.unscoped.find(params[:id])
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
    @deleted_organization_roles ? organization_roles.deleted : organization_roles
  end
end
