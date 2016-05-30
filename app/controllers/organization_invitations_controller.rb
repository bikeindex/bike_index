=begin
*****************************************************************
* File: app/controllers/organizationInvitations_controller.rb 
* Name: Class OrganizationInvitationsController 
* Set some methods to organization of organization invited.
*****************************************************************
=end

class OrganizationInvitationsController < ApplicationController
  before_filter :authenticate_user
  before_filter :find_organization
  before_filter :require_admin

  layout "organization"

=begin
  Name: new
  Params: none
  Explication: create a new instance for organization invitation
  Return: @organizationInvitation 
=end  
  def new
    @organizationInvitation = OrganizationInvitation.new
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@organizationInvitation)
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_message(@organizationInvitation.kind_of?(OrganizationInvitation))
    return @organizationInvitation
  end

=begin
  Name: create
  Params: receive the parameters about the organization invitation. They are: invitee_email, organizationInvitation, invitee_name e membership_role.
  Explication: method used to do invitee and store information about new organization in databases.
  Return: current user or current organization or redirect to edit organization or redirect to new organization invitation  
=end
  def create
    @organization = current_organization
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@organization)
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_message(@organization.kind_of?(current_organization))
    if @organization.available_invitation_count > 0
      @organizationInvitation = OrganizationInvitation.new(invitee_email: 
      params[:organizationInvitation][:invitee_email], invitee_name:
      params[:organizationInvitation][:invitee_name], organization: @organization, inviter: current_user,              membership_role: params[:organizationInvitation][:membership_role])
      @organizationInvitation.inviter = current_user
      if @organizationInvitation.save
        redirect_to edit_organization_url(@organization), notice: "#{@organizationInvitation.invitee_email} was invited to #{@organization.name}!"
      else
        flash[:error] = "Whoops! Looks like we're missing some information"
        redirect_to new_organizationInvitation_url
      end
    else
      redirect_to edit_organization_url(@organization), notice: "Oh no! You appear to be out of invitations. Contact us if this seems wrong"
    end
  end

=begin
  Name: find_organization
  Params: organization's id
  Explication: method used to find the specific organization by id
  Return: @organization 
=end
  def find_organization
    @organization = Organization.find_by_slug(params[:organization_id])
    # method assert used to debug, checking if the condition is always true for the program to continue running.
    assert_object_is_not_null(@organization)
    return @organization
  end

=begin
  Name: require_admin
  Params: receive the organization which will be verified if current user is your administrator
  Explication: method used to verify if current user is organization administrator 
  Return: nothing 
=end
  def require_admin
    unless current_user.is_admin_of?(@organization)
      flash[:error] = "You gotta be an organization administrator to do that!"
      redirect_to user_home_url and return
    end
  end

end
