class Admin::StolenBikesController < Admin::BaseController
  include SortableTable
  before_action :find_bike, only: [:edit, :destroy, :approve, :update, :regenerate_alert_image]
  before_action :set_period, only: [:index]
  helper_method :available_stolen_records

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @stolen_records = available_stolen_records.page(page).per(per_page).includes(:bike)
      .reorder("stolen_records.#{sort_column} #{sort_direction}")
  end

  def approve
    @bike.current_stolen_record.update_attribute :approved, true
    ApproveStolenListingWorker.perform_async(@bike.id)
    flash[:success] = "Stolen Bike was approved"
    redirect_to edit_admin_stolen_bike_url(@bike)
  end

  def show
    redirect_to edit_admin_stolen_bike_url(id: params[:id], stolen_record_id: params[:stolen_record_id])
  end

  def edit
    @customer_contact = CustomerContact.new(user_email: @bike.owner_email)
  end

  def update
    if %w[regenerate_alert_image delete].include?(params[:update_action])
      update_image
    else
      BikeUpdator.new(user: current_user, bike: @bike, b_params: {bike: permitted_parameters}).update_ownership
      if @bike.update(permitted_parameters)
        SerialNormalizer.new({serial: @bike.serial_number}).save_segments(@bike.id)
        flash[:success] = "Bike was successfully updated."
      else
        flash[:error] = "Unable to update!"
        render action: "edit"
        return
      end
    end
    redirect_back(fallback_location: edit_admin_stolen_bike_url(@bike))
  end

  protected

  def sortable_columns
    %w[created_at date_stolen]
  end

  def permitted_parameters
    params.require(:bike).permit(BikeCreator.old_attr_accessible)
  end

  def find_bike
    if ParamsNormalizer.boolean(params[:stolen_record_id])
      @stolen_record = StolenRecord.unscoped.find(params[:id])
      @bike = Bike.unscoped.find_by_id(@stolen_record.bike_id)
    else
      @bike = Bike.unscoped.find_by_id(params[:id])
      @stolen_record = @bike.current_stolen_record
    end
    @current_stolen_record = @stolen_record.present? && @stolen_record.id == @bike.current_stolen_record&.id
    @bike
  end

  def update_image
    selected_image = @bike.public_images.find_by_id(params[:public_image_id])
    if params[:public_image_id].present? && selected_image.blank?
      flash[:error] = "Unable to find that image!"
    elsif params[:update_action] == "delete"
      selected_image.destroy
      flash[:success] = "Image deleted"
      @bike.current_stolen_record.generate_alert_image
    elsif params[:update_action] == "regenerate_alert_image"
      if @bike.current_stolen_record.generate_alert_image(bike_image: selected_image)
        flash[:success] = "Promoted alert bike image updated."
      else
        flash[:error] = "Could not update promoted alert image."
      end
    else
      flash[:error] = "Unknown action!"
    end
  end

  def available_stolen_records
    return @available_stolen_records if defined?(@available_stolen_records)
    @unapproved_only = !ParamsNormalizer.boolean(params[:search_unapproved])
    if @unapproved_only
      available_stolen_records = StolenRecord.current.unapproved
      @only_with_location = !ParamsNormalizer.boolean(params[:without_location])
      if @only_with_location
        @unapproved_without_location_count = available_stolen_records.without_location.count
        available_stolen_records = available_stolen_records.with_location
      end
    else
      available_stolen_records = StolenRecord
    end

    if params[:search_location].present?
      bounding_box = Geocoder::Calculations.bounding_box(params[:search_location], @distance)
      available_stolen_records = available_stolen_records.within_bounding_box(bounding_box)
    end

    available_stolen_records =

    @time_range_column = sort_column if %w[date_stolen].include?(sort_column)
    @time_range_column ||= "created_at"
    @available_stolen_records = available_stolen_records.where(@time_range_column => @time_range)
  end
end
