class Admin::StolenBikesController < Admin::BaseController
  include SortableTable
  before_action :find_bike, only: %i[edit update]
  helper_method :available_stolen_records

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @stolen_records = pagy(available_stolen_records.includes(:bike)
      .reorder("stolen_records.#{sort_column} #{sort_direction}"), limit: @per_page, page: permitted_page)
  end

  def approve
    if params[:id] == "multi_approve"
      stolen_record_ids = defined?(params[:sr_selected].keys) ? params[:sr_selected].keys : params[:sr_selected]
      if stolen_record_ids.any?
        stolen_record_ids.each do |id|
          stolen_record = StolenRecord.unscoped.find(id)
          stolen_record.update_attribute :approved, true
          StolenBike::ApproveStolenListingJob.perform_async(stolen_record.bike_id)
        end
        # Lazy pluralize hack
        flash[:success] = "#{stolen_record_ids.count} stolen #{(stolen_record_ids.count == 1) ? "bike" : "bikes"} approved!"
      else
        flash[:error] = "No stolen records selected to approve!"
      end
      redirect_back(fallback_location: admin_stolen_bikes_url)
    else
      find_bike
      @bike.current_stolen_record.update_attribute :approved, true
      StolenBike::ApproveStolenListingJob.perform_async(@bike.id)
      flash[:success] = "Stolen Bike was approved"
      redirect_to edit_admin_stolen_bike_url(@bike)
    end
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
      BikeServices::Updator.new(user: current_user, bike: @bike, params:).update_ownership

      if @bike.update(permitted_parameters)
        SerialNormalizer.new(serial: @bike.serial_number).save_segments(@bike.id)
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
    params.require(:bike).permit(BikeServices::Creator.old_attr_accessible)
  end

  def find_bike
    if InputNormalizer.boolean(params[:stolen_record_id])
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
      return
    elsif params[:update_action] == "delete"
      selected_image.skip_update = true # Prevent autorunning of job
      selected_image.destroy
      flash[:success] = "Image deleted"
      selected_image = nil
    elsif params[:update_action] != "regenerate_alert_image"
      flash[:error] = "Unknown action!"
      return
    end

    # Running this inline causes the server to break. So background it
    StolenBike::AfterStolenRecordSaveJob.perform_async(@bike.current_stolen_record_id, true,
      selected_image&.id)
    # Lazy hack to wait for it to process
    sleep 1
    flash[:success] ||= "Promoted alert bike image updated."
  end

  def available_stolen_records
    return @available_stolen_records if defined?(@available_stolen_records)
    @unapproved_only = !InputNormalizer.boolean(params[:search_unapproved])
    @only_without_location = InputNormalizer.boolean(params[:search_without_location])
    if @unapproved_only
      available_stolen_records = StolenRecord.current.unapproved
      unless @only_without_location
        @unapproved_without_location_count = available_stolen_records.without_location.count
        available_stolen_records = available_stolen_records.with_location
      end
    else
      available_stolen_records = StolenRecord
    end
    unless InputNormalizer.boolean(params[:search_include_spam])
      available_stolen_records = available_stolen_records.not_spam
    end

    @with_promoted_alert = InputNormalizer.boolean(params[:search_with_promoted_alert])
    if @with_promoted_alert
      available_stolen_records = available_stolen_records.with_theft_alerts_paid_or_admin
    end

    # We always render distance
    @distance = GeocodeHelper.permitted_distance(params[:search_distance], default_distance: 50)
    if !@only_without_location && params[:search_location].present?
      bounding_box = GeocodeHelper.bounding_box(params[:search_location], @distance)
      available_stolen_records = available_stolen_records.within_bounding_box(bounding_box)
    end

    @time_range_column = sort_column if %w[date_stolen].include?(sort_column)
    @time_range_column ||= "created_at"
    @available_stolen_records = available_stolen_records.where(@time_range_column => @time_range)
  end
end
