=begin
*****************************************************************
* File: app/controllers/admin/ads_controller.rb
* Name: Class Admin::AdsController
* CRUD of admin
*****************************************************************
=end

class Admin::AdsController < Admin::BaseController
  before_filter :find_ad, except: [:index, :new, :create]
  before_filter :find_organizations, only: [:new, :edit]

  def index
    @ads = Ad.all
  end

  def show
    redirect_to edit_admin_ad_url(@ad)
  end

  def edit
    
  end

  def update
    if @ad.update_attributes(params[:ad])
      flash[:notice] = "Ad Saved!"
      redirect_to admin_ad_url(@ad)
    else
      render action: :edit
    end
  end

  def new
    @ad = Ad.new
  end

  def create
    @ad = Ad.create(params[:ad])
    if @ad.save
      flash[:notice] = "Ad Created!"
      redirect_to edit_admin_ad_url(@ad)
    else
      render action: :new
    end
  end


  protected

  def find_ad
    @ad = Ad.find(params[:id])
  end

  def find_organizations
    @organizations = Organization.all
  end

end
