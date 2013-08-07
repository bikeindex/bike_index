class MembershipsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :find_membership
  before_filter :require_admin_of_membership!

  def update
    @user = @membership.user
    if @membership.update_attributes(role: params[:membership][:role])
      redirect_to user_url(@user), notice: "Updated user's settings."
    else
      redirect_to user_url(@user), notice: "Oops, update failed."
    end
  end

  def destroy
    @membership = current_organization.memberships.find(params[:id])
    @membership.destroy
    flash[:notice] = "Membership Destroyed. User booted from organization."
    redirect_to root_url
  end

  def find_membership
    @membership = Membership.find(params[:id])
  end

  def require_admin_of_membership!
    require_admin!
    unless @membership.organization_id = current_organization.id 
      flash[:error] = "You gotta be an organization administrator to do that!"
      redirect_to root_url
    end
  end

end
