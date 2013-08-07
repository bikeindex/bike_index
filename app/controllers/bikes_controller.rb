class OwnershipNotSavedError < StandardError
end

class BikeNotSavedError < StandardError
end

class BikeCreatorError < StandardError
end

class BikeUpdatorError < StandardError
end

class BikeTyperError < StandardError
end

class BikesController < ApplicationController
  before_filter :ensure_user_for_edit, only: [:edit, :update]
  before_filter :ensure_user_for_new, only: [:new, :create]
  layout 'no_container'

  def index
    @title = "Bikes"
    @search_type = SearchBikes.new(params).search_type
    bikes = SearchBikes.new(params).bikes
    bikes = bikes.page(params[:page]).per_page(24)
    @bikes = bikes.decorate
    render :layout => 'application'
  end

  def show
    bike = Bike.find(params[:id])
    @title = "#{bike.manufacturer.name}"
    @components = bike.components.decorate
    @bike = bike.decorate
    @stolen_notification = StolenNotification.new if @bike.stolen
    respond_to do |format|
      format.html
      format.png  { render :qrcode => bike_url(@bike), :level => :h, :unit => 50 }
    end
  end

  def spokecard
    @title = "Bike spokecard"
    @bike = Bike.find(params[:id])
    if @bike.verified?
      render layout: false
    else
      flash[:error] = "Whoops, we can't make a spoke card for that bike. Perhaps it wasn't registered at a bike shop?"
      redirect_to user_home_url
    end
  end

  def new
    @title = "New bike"
    b_param = BParam.create(creator_id: current_user.id, params: params)
    @bike = BikeCreator.new(b_param).new_bike
    if @bike.errors.any?
      flash[:notice] = @bike.errors.full_messages
    end
    render layout: 'no_header'
  end


  def create
    users_b_params = BParam.where(creator_id: current_user.id)
    begin
      @b_param = users_b_params.find(params[:bike][:b_param_id])
    rescue
      @bike = Bike.new
      flash[:error] = "Oops, that isn't your bike"
      redirect_to action: :new, layout: 'no_header' and return
    end
    if @b_param.created_bike.present?
      redirect_to edit_bike_url(@b_param.created_bike) and return
    end
    @b_param.update_attributes(params: params)
    @bike = BikeCreator.new(@b_param).create_bike
    if @bike.errors.any?
      render action: :new, layout: 'no_header' and return
    end
    if @bike.payment_required
      redirect_to new_charges_url(b_param_id: @b_param.id) and return
    else
      redirect_to edit_bike_url(@bike), notice: "Bike successfully added to the index!"      
    end
  end


  def edit
    bike = Bike.find(params[:id])
    @title = "Edit #{bike.manufacturer.name}"
    begin
      BikeUpdator.new(user: current_user, b_params: params).ensure_ownership!
      rescue UserNotLoggedInError => e
        flash[:error] = e.message
        redirect_to new_user_path and return
      rescue => e
        flash[:error] = e.message
        redirect_to bike_path(bike) and return
    end
    @twined_ctypes = Ctype.where(has_twin_part: true).map(&:id).join(",")
    @bike = bike.decorate
  end


  def update
    begin
      bike = BikeUpdator.new(user: current_user, b_params: params).update_available_attributes
    rescue => e
      flash[:error] = e.message
      redirect_to bike_path(params[:id]) and return
    end
    @twined_ctypes = Ctype.where(has_twin_part: true).map(&:id).join(",")
    @bike = bike.decorate 
    flash[:notice] = "Bike successfully updated!" unless bike.errors.any?
    render action: :edit, layout: 'no_header'
  end

protected
  def ensure_user_for_new
    unless current_user.present?
      flash[:error] = "Whoops! You have to sign up to be able to do that"
      redirect_to new_user_path and return
    end
  end

  def ensure_user_for_edit
    unless current_user.present?
      bike = Bike.find(params[:id])
      flash[:error] = "Whoops! You have to sign up to be able to do that"
      redirect_to bike_path(bike) and return
    end
  end

end
