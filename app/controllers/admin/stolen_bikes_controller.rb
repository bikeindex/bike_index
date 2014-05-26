class BikeNotSavedError < StandardError
end

class Admin::StolenBikesController < Admin::BaseController
  before_filter :find_bike, only: [:edit, :destroy, :approve, :update]

  def index
    if params[:unapproved]
      ids = StolenRecord.where(approved: false).pluck(:bike_id)
      bikes = Bike.where('id in (?)', ids)
      @verified_only = true
    else
      bikes = Bike.where(stolen: true).order("created_at desc")
    end
    bikes = bikes.paginate(page: params[:page]).per_page(50)
    @bikes = bikes.decorate
  end

  def approve
    @bike.current_stolen_record.update_attribute :approved, true
    redirect_to edit_admin_stolen_bike_url(@bike), notice: 'Bike was approved.'
  end

  def destroy
    @bike.destroy
    flash[:notice] = "Bike deleted!"
    redirect_to admin_bikes_url
  end

  def show
    redirect_to edit_admin_stolen_bike_url
  end

  def edit
    @stolen_record = @bike.current_stolen_record
    @customer_contact = CustomerContact.new
    @bike = @bike.decorate
  end

  def update
    BikeUpdator.new(user: current_user, b_params: params).update_ownership
    @bike = @bike.decorate
    if @bike.update_attributes(params[:bike])
      SerialNormalizer.new({serial: @bike.serial_number}).save_segments(@bike.id)
      redirect_to edit_admin_stolen_bike_url(@bike), notice: 'Bike was successfully updated.'
    else
      render action: "edit"
    end
  end

  protected

  def find_bike
    @bike = Bike.unscoped.find(params[:id])
  end
end
