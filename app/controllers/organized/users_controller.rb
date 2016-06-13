module Organized
  class UsersController < Organized::BaseController
    layout 'application_revised'
    before_filter :ensure_admin!
    before_filter :find_invitation_or_membership, only: [:edit, :update, :destroy]
    before_filter :reject_self_updates, only: [:update, :destroy]
    skip_before_filter :ensure_member!

    def index
      @organization_invitations = current_organization.organization_invitations.unclaimed
      @memberships = current_organization.memberships
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
        @organization_invitation.update_attributes(invitee_name: params[:organization_invitation][:name],
          membership_role: params[:organization_invitation][:membership_role])
        flash[:success] = "Updated invitation for #{@organization_invitation.invitee_email}"
      else
        @membership.update_attributes(role: params[:membership][:role])
        flash[:success] = "Updated membership for #{@membership.user.email}"
      end
      redirect_to organization_users_path(organization_id: current_organization.id)
    end

    def destroy
      if @is_invitation
        @organization_invitation.destroy
        flash[:success] = 'Deleted user from your organization'
      else
        @membership.destroy
        flash[:success] = 'Deleted user from your organization'
      end
      new_invites_count = current_organization.available_invitation_count + 1
      current_organization.update_attribute :available_invitation_count, new_invites_count
      redirect_to organization_users_path(organization_id: current_organization.id)
    end

    def new
      @organization_invitation = OrganizationInvitation.new(organization_id: current_organization.id)
      @page_errors = @organization_invitation.errors
    end

    def create
      if current_organization.available_invitation_count > 0
        @organization_invitation = OrganizationInvitation.new(
          invitee_email: params[:organization_invitation][:invitee_email],
          invitee_name: params[:organization_invitation][:invitee_name],
          organization: current_organization,
          inviter: current_user,
          membership_role: params[:organization_invitation][:membership_role])
        # @organization_invitation.inviter = current_user
        if @organization_invitation.save
          flash[:success] = "#{@organization_invitation.invitee_email} was invited to #{current_organization.name}!"
          redirect_to organization_users_path(organization_id: current_organization)
        else
          flash[:error] = "Whoops! Looks like we're missing some information"
          render :new
        end
      else
        flash[:error] = "#{current_organization.name} is out of user invitations. Contact support@bikeindex.org"
        redirect_to organization_users_path(organization_id: current_organization)
      end
    end

    private

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
  end
end
