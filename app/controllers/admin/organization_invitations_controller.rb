class Admin::OrganizationInvitationsController < Admin::BaseController
  before_filter :find_organizationInvitation, only: [:edit, :update, :destroy]
  
  def index
    @organizationInvitations = OrganizationInvitation.all
  end
  
  def new
    @organizationInvitation = OrganizationInvitation.new
    @organizations = Organization.all
  end

  def show
    @organization = Organization.find(params[:id])
    @organizations = Organization.all
    @organizationInvitations = OrganizationInvitation.where(organization_id: @organization.id)
    @organizationInvitation = OrganizationInvitation.new(organization_id: @organization.id)
  end

  def edit
    @organizations = Organization.all
  end

  def update
    if @organizationInvitation.update_attributes(params[:organizationInvitation])
      flash[:notice] = "Invitation Saved!"
      redirect_to admin_organizationInvitations_url
    else
      render action: :edit
    end
  end

  def create
    @organizationInvitation = OrganizationInvitation.new(params[:organizationInvitation])
    @organizationInvitation.inviter = current_user
    
    @organization = @organizationInvitation.organization
    if @organization.available_invitation_count > 0
      if @organizationInvitation.save
        redirect_to admin_organization_url(@organizationInvitation.organization.slug), notice: "#{@organizationInvitation.invitee_email} was invited to #{@organization.name}!"
      else
        flash[:error] = "Oh no! Error problem things! The invitation was not saved. Maybe we're missing some information?"
        redirect_to edit_admin_organizationInvitation_url(@organizationInvitation.organization.id)
      end
    else
      redirect_to root_url, notice: "Oh no! This organization has no more invitations."
    end
  end

  def destroy
    @organizationInvitation.destroy
    redirect_to admin_memberships_url
  end



  protected

  def find_organizationInvitation
    @organizationInvitation = OrganizationInvitation.find(params[:id])
  end

end
