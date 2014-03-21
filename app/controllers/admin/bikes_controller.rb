class BikeNotSavedError < StandardError
end

class Admin::BikesController < Admin::BaseController
  before_filter :find_bike, only: [:edit, :destroy, :update]

  def index
    if params[:email]
      user = User.fuzzy_email_find(params[:email])
      @bikes = Bike.find(user.bikes) if user.present?
    else 
      @bikes = Bike.limit(100)
    end
  end

  def duplicates
    @bike_groups = []
    serials = Bike.all.map(&:serial_number)
    new_ary = serials.select {|item| serials.count(item) > 1}
    new_ary.uniq.each do |serial|
      @bike_groups << Bike.where(serial_number: serial)
    end
  end

  def destroy
    @bike.destroy
    flash[:notice] = "Bike deleted!"
    redirect_to admin_bikes_url
  end

  def show
    redirect_to edit_admin_bike_url
  end

  def edit
    @bike = @bike.decorate
  end

  def update
    BikeUpdator.new(user: current_user, b_params: params).update_ownership
    @bike = @bike.decorate
    if @bike.update_attributes(params[:bike])
      SerialNormalizer.new({serial: @bike.serial_number}).save_segments(@bike.id)
      redirect_to edit_admin_bike_url(@bike), notice: 'Bike was successfully updated.'
    else
      render action: "edit"
    end
  end

  protected

  def find_bike
    @bike = Bike.unscoped.find(params[:id])
  end
end
