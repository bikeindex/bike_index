class Admin::MembershipsController < Admin::BaseController
  include SortableTable
  before_action :find_membership, only: [:show, :edit, :update, :destroy]
  before_action :find_organizations

  def index
    @per_page = params[:per_page] || 50
    @pagy, @memberships = pagy(
      matching_memberships.includes(:user, :sender, :organization).reorder("memberships.#{sort_column} #{sort_direction}"),
      limit: @per_page)
  end

  def show
    redirect_to edit_admin_membership_path
  end

  def new
    @membership = Membership.new(organization_id: current_organization&.id)
  end

  def edit
  end

  def update
    if @membership.update(permitted_parameters)
      flash[:success] = "Membership Saved!"
      redirect_to admin_membership_url(@membership)
    else
      render action: :edit
    end
  end

  def create
    @membership = Membership.new(permitted_parameters.merge(sender: current_user))
    if @membership.save
      flash[:success] = "Membership Created!"
      redirect_to admin_membership_url(@membership)
    else
      render action: :new
    end
  end

  def destroy
    @membership.destroy
    flash[:success] = "membership deleted successfully"
    redirect_to admin_memberships_url
  end

  protected

  def sortable_columns
    %w[created_at invited_email sender_id claimed_at organization_id role deleted_at]
  end

  def permitted_parameters
    params.require(:membership).permit(:organization_id, :user_id, :role, :invited_email)
  end

  def find_membership
    @membership = Membership.unscoped.find(params[:id])
  end

  def find_organizations
    @organizations = Organization.all
  end

  def matching_memberships
    memberships = if current_organization.present?
      current_organization.memberships
    else
      Membership.all
    end
    @deleted_memberships = current_organization&.deleted? || InputNormalizer.boolean(params[:search_deleted])
    @deleted_memberships ? memberships.deleted : memberships
  end
end
