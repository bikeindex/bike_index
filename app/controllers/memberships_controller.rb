class MembershipsController < ApplicationController
  before_filter :authenticate_user
  before_filter :find_membership
  before_filter :require_admin

  layout "organization"

  def edit
    @user = @membership.user
    bikes = Bike.where(creator_id: @user.id).where(creation_organization_id: @organization.id).order("created_at asc")
    @bikes = BikeDecorator.decorate_collection(bikes)
  end

  def update
    if @membership.update_attributes(role: params[:membership][:role])
      redirect_to edit_organization_path(id: @organization.slug), notice: "Updated user's settings."
    else
      redirect_to edit_organization_path(id: @organization.slug), notice: "Oops, update failed."
    end
  end

  def destroy
    @membership.destroy
    flash[:notice] = "Membership Destroyed. User booted from organization."
    redirect_to organization_path(@organization)
  end

  def find_membership
    @membership = Membership.find(params[:id])
  end


protected

  def find_membership
    @membership = Membership.find(params[:id])
    @organization = @membership.organization
  end

  def require_admin
    unless current_user.is_admin_of?(@organization)
      flash[:error] = "You gotta be an organization administrator to do that!"
      redirect_to user_home_url and return
    end
  end

end
