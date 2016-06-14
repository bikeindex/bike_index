module Organized
  class UsersController < Organized::AdminController
    before_filter :find_invitation_or_membership, only: [:edit, :update, :destroy]
    before_filter :reject_self_updates, only: [:update, :destroy]

    def index
      @organization_invitations = current_organization.organization_invitations.unclaimed
      @memberships = current_organization.memberships.order('created_at desc')
    end

    def edit
      if @is_invitation
        @organization_invitation = current_organization.organization_invitations.unclaimed.find(params[:id])
      else
        @membership = current_organization.memberships.find(params[:id])
      end
      @name = @organization_invitation && @organization_invitation.invitee_name || @membership && @membership.user.name
    end

    def update
      if @is_invitation
        @organization_invitation.update_attributes(update_organization_invitation_params)
        flash[:success] = "Updated invitation for #{@organization_invitation.invitee_email}"
      else
        @membership.update_attributes(update_membership_params)
        flash[:success] = "Updated membership for #{@membership.user.email}"
      end
      redirect_to current_index_path
    end

    def destroy
      if @is_invitation
        @organization_invitation.destroy
      else
        @membership.destroy
      end
      flash[:success] = 'Deleted user from your organization'
      new_invites_count = current_organization.available_invitation_count + 1
      current_organization.update_attribute :available_invitation_count, new_invites_count
      redirect_to current_index_path
    end

    def new
      @organization_invitation = OrganizationInvitation.new(organization_id: current_organization.id)
      @page_errors = @organization_invitation.errors
    end

    def create
      unless current_organization.available_invitation_count > 0
        flash[:error] = "#{current_organization.name} is out of user invitations. Contact support@bikeindex.org"
        redirect_to current_index_path and return
      end
      @organization_invitation = OrganizationInvitation.new(create_organization_invitation_params)
      if @organization_invitation.save
        flash[:success] = "#{@organization_invitation.invitee_email} was invited to #{current_organization.name}!"
        redirect_to current_index_path
      else
        flash[:error] = "Whoops! Looks like we're missing some information"
        render :new
      end
    end

    private

    def current_index_path
      organization_users_path(organization_id: current_organization.to_param)
    end

    def find_invitation_or_membership
      @is_invitation = params[:is_invitation]
      if @is_invitation
        @organization_invitation = current_organization.organization_invitations.unclaimed.find(params[:id])
      else
        @membership = current_organization.memberships.find(params[:id])
      end
    end

    def reject_self_updates
      if @membership && @membership.user == current_user
        flash[:error] = "Sorry, you can't remove yourself from the organization. Contact us at support@bikeindex.org if this is problematic."
        redirect_to organization_users_path(organization_id: current_organization) and return
      end
    end

    def create_organization_invitation_params
      {
        invitee_email: params[:organization_invitation][:invitee_email],
        invitee_name: params[:organization_invitation][:invitee_name],
        organization: current_organization,
        inviter: current_user,
        membership_role: params[:organization_invitation][:membership_role]
      }
    end

    def update_organization_invitation_params
      {
        invitee_name: params[:organization_invitation][:name],
        membership_role: params[:organization_invitation][:membership_role]
      }
    end

    def update_membership_params
      { role: params[:membership][:role] }
    end
  end
end
