class OrganizationDealsController < ApplicationController

  def new
    @organization_deal = OrganizationDeal.new
    @organization_id = Organization.find(params[:organization_id])
    @name = params[:deal_name]
  end

  def create
    @organization_deal = OrganizationDeal.new(params[:organization_deal])
    if @organization_deal.save
      flash[:notice] = "Thank you! We will contact Kozy's and register your bike on the Index!"
      redirect_to about_url
    else
      render action: :new
    end
  end


end