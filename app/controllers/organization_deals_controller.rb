=begin
*****************************************************************
* File: app/controllers/organization_deals_controller.rb 
* Name: Class OrganizationDealsController 
* Set some methods to deal with organization
*****************************************************************
=end

class OrganizationDealsController < ApplicationController

  def new
    @organizationDeal = OrganizationDeal.new
    @organization = Organization.find(params[:organization_id])
    @name = params[:deal_name]
  end

  def create
    @organizationDeal = OrganizationDeal.new(params[:organizationDeal])
    if @organizationDeal.save
      flash[:notice] = "Thank you! We will contact Kozy's and register your bike on the Index!"
      redirect_to about_url
    else
      render action: :new
    end
  end


end