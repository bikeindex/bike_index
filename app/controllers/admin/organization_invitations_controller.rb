class Admin::OrganizationInvitationsController < Admin::BaseController
  before_filter :find_organization
  before_filter :find_organization_invitation, only: [:edit, :update, :destroy]
  
  def index
    @organization_invitations = OrganizationInvitation.all
  end
  
  def new
    @organization_invitation = OrganizationInvitation.new
    @organizations = Organization.all
  end

  def show
    @organizations = Organization.all
    @organization_invitations = OrganizationInvitation.where(organization_id: @organization.id)
    @organization_invitation = OrganizationInvitation.new(organization_id: @organization.id)
  end

  def edit
    @organizations = Organization.all
  end

  def update
    if @organization_invitation.update_attributes(permitted_parameters)
      flash[:success] = 'Invitation Saved!'
      redirect_to admin_organization_invitations_url
    else
      render action: :edit
    end
  end

  def create
    @organization_invitation = OrganizationInvitation.new(permitted_parameters)
    @organization_invitation.inviter = current_user
    
    @organization = @organization_invitation.organization
    if @organization.available_invitation_count > 0
      if @organization_invitation.save
        flash[:success] = "#{@organization_invitation.invitee_email} was invited to #{@organization.name}!"
        redirect_to admin_organization_url(@organization_invitation.organization.slug)
      else
        flash[:error] = "Oh no! Error problem things! The invitation was not saved. Maybe we're missing some information?"
        redirect_to edit_admin_organization_invitation_url(@organization_invitation.id, organization_id: @organization_invitation.organization.to_param)
      end
    else
      flash[:error] = 'Oh no! This organization has no more invitations. Email contact@bikeindex.org for help'
      redirect_to root_url
    end
  end

  def destroy
    @organization_invitation.destroy
    redirect_to admin_memberships_url
  end

  protected

  def find_organization
    @organization = current_organization
  end

  def permitted_parameters
    params.require(:organization_invitation).permit(OrganizationInvitation.old_attr_accessible)
  end

  def find_organization_invitation
    @organization_invitation = OrganizationInvitation.find(params[:id])
  end
end
