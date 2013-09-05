class LocksController < ApplicationController

  def new
    @organization_deal = OrganizationDeal.new(params[:organization_deal])
  end

  def create
    @organization_deal = OrganizationDeal.new(params[:organization_deal])
    if @organization_deal.save
      flash[:notice] = "Lock created successfully!"
      redirect_to wher_lock_url(@lock)
    else
      render action: :new
    end
  end


end