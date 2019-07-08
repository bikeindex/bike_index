module Organized
  class UsersController < Organized::AdminController
    include SortableTable
    before_filter :find_membership, only: [:edit, :update, :destroy]
    before_filter :reject_self_updates, only: [:update, :destroy]

    def index
      page = params[:page] || 1
      per_page = params[:per_page] || 25
      @memberships = matching_memberships.reorder("memberships.#{sort_column} #{sort_direction}")
                                         .page(page).per(per_page)
    end

    def edit
    end

    def update
      @membership.update_attributes(permitted_update_params)
      flash[:success] = "Updated membership for #{@membership.user.email}"
      redirect_to current_index_path
    end

    def destroy
      @membership.destroy
      flash[:success] = "Deleted user from your organization"
      redirect_to current_index_path
    end

    def new
      @organization_invitation = OrganizationInvitation.new(organization_id: current_organization.id)
      @page_errors = @organization_invitation.errors
    end

    def create
      unless current_organization.remaining_invitation_count > 0
        flash[:error] = "#{current_organization.name} is out of user invitations. Contact support@bikeindex.org"
        redirect_to current_index_path and return
      end
      @membership = Membership.new(permitted_create_params)
      if @membership.save
        flash[:success] = "#{@membership.invited_email} was invited to #{current_organization.name}!"
        redirect_to current_index_path
      else
        flash[:error] = "Whoops! Looks like we're missing some information"
        render :new
      end
    end

    private

    def sortable_columns
      %w[created_at invited_email sender_id claimed_at]
    end

    def matching_memberships
      memberships = current_organization.memberships
    end

    def current_index_path
      organization_users_path(organization_id: current_organization.to_param)
    end

    def find_membership
      @membership = current_organization.memberships.find(params[:id])
    end

    def reject_self_updates
      if @membership && @membership.user == current_user
        flash[:error] = "Sorry, you can't remove yourself from the organization. Contact us at support@bikeindex.org if this is problematic."
        redirect_to organization_users_path(organization_id: current_organization) and return
      end
    end

    def permitted_update_params
      params.require(:membership).permit(:role).merge(organization_id: current_organization.id)
    end

    def permitted_create_params
      params.require(:membership).permit(:role, :invited_email)
            .merge(organization: current_organization, sender: current_user)
    end

    def update_membership_params
      { role: params.dig(:membership, :role) }
    end
  end
end
