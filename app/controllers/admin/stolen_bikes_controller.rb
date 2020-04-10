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
    @bike.update_attribute :approved_stolen, true
    ApproveStolenListingWorker.perform_async(@bike.id)
    flash[:success] = "Stolen Bike was approved"
    redirect_to edit_admin_stolen_bike_url(@bike)
  end

  def show
    redirect_to edit_admin_stolen_bike_url
  end

  def edit
    @customer_contact = CustomerContact.new(user_email: @bike.owner_email)
    @bike = @bike.decorate
  end

  def update
    if params[:public_image_id].present?
      update_image
    else
      BikeUpdator.new(user: current_user, bike: @bike, b_params: { bike: permitted_parameters }).update_ownership
      @bike = @bike.decorate
      if @bike.update_attributes(permitted_parameters)
        SerialNormalizer.new({ serial: @bike.serial_number }).save_segments(@bike.id)
        flash[:success] = "Bike was successfully updated."
        redirect_to edit_admin_stolen_bike_url(@bike)
      else
        flash[:error] = "Unable to update!"
        render action: "edit"
      end
    end
  end

  protected

  def sortable_columns
    %w[created_at date_stolen]
  end

  def permitted_parameters
    params.require(:bike).permit(Bike.old_attr_accessible)
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
    if selected_image.blank?
      flash[:error] = "Unable to find that image!"
    elsif params[:update_action] == "delete"
      selected_image.destroy
      flash[:success] = "Image deleted"
    elsif params[:update_action] == "regenerate_alert_image"
      if @bike.current_stolen_record.generate_alert_image(bike_image: selected_image)
        flash[:success] = "Promoted alert bike image updated."
      else
        flash[:error] = "Could not update promoted alert image."
      end
    else
      flash[:error] = "Unknown action!"
    end
    redirect_to edit_admin_stolen_bike_url(@bike)
  end

  def available_stolen_records
    return @available_stolen_records if defined?(@available_stolen_records)
    @verified_only = ParamsNormalizer.boolean(params[:unapproved])
    if @verified_only
      available_stolen_records = StolenRecord
    else
      available_stolen_records = StolenRecord.approveds
    end
    @available_stolen_records = available_stolen_records.where(created_at: @time_range)
  end
end
