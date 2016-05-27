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
  
  def new
    @organizationInvitation = OrganizationInvitation.new
    assert_object_is_not_null(@organizationInvitation)
    assert_message(@organizationInvitation.kind_of?(OrganizationInvitation))
    return @organizationInvitation
  end

  def create
    @organization = current_organization
    assert_object_is_not_null(@organization)
    assert_message(@organization.kind_of?(current_organization))
    if @organization.available_invitation_count > 0
      @organizationInvitation = OrganizationInvitation.new(invitee_email: params[:organizationInvitation][:invitee_email], invitee_name: params[:organizationInvitation][:invitee_name], organization: @organization, inviter: current_user, membership_role: params[:organizationInvitation][:membership_role])
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

  def find_organization
    @organization = Organization.find_by_slug(params[:organization_id])
    assert_object_is_not_null(@organization)
    return @organization
  end

  def require_admin
    unless current_user.is_admin_of?(@organization)
      flash[:error] = "You gotta be an organization administrator to do that!"
      redirect_to user_home_url and return
    end
  end

end
