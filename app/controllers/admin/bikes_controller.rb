class Admin::BikesController < Admin::BaseController
  include SortableTable
  before_action :find_bike, only: %i[edit update show]
  before_action :set_period, only: %i[index missing_manufacturer]
  around_action :set_reading_role, only: %i[index show]

  def index
    @page = params[:page] || 1
    @per_page = params[:per_page] || 100
    @bikes = available_bikes.includes(:creation_organization, :current_ownership, :paint)
      .reorder("bikes.#{sort_column} #{sort_direction}")
      .page(@page).per(@per_page)
  end

  def missing_manufacturer
    @page = params[:page] || 1
    @per_page = params[:per_page] || 100
    @bikes = missing_manufacturer_bikes.includes(:creation_organization, :current_ownership, :paint)
      .page(@page).per(@per_page)
  end

  def update_manufacturers
    if params[:manufacturer_id].present? && params[:bikes_selected].present?
      manufacturer_id = params[:manufacturer_id]
      bike_ids = params[:bikes_selected].keys
      bike_ids.each do |bid|
        Bike.unscoped.find_by_id(bid)&.update(manufacturer_id: manufacturer_id, manufacturer_other: nil)
      end
      # Needs to happen after the manufacturer has been assigned
      Bike.unscoped.where(id: bike_ids).distinct.pluck(:model_audit_id)
        .each_with_index { |i, inx| UpdateModelAuditWorker.perform_in(inx * 15, i) }
      flash[:success] = "Success. #{bike_ids.count} Bikes updated"
    else
      flash[:notice] = "Sorry, you need to add bikes and a manufacturer"
    end
    redirect_back(fallback_location: root_url)
  end

  def duplicates
    duplicate_groups = if params[:show_ignored]
      DuplicateBikeGroup.order("created_at desc")
    else
      DuplicateBikeGroup.unignored.order("created_at desc")
    end
    @page = params[:page] || 1
    @per_page = params[:per_page] || 25
    @duplicate_groups = duplicate_groups.page(@page).per(@per_page)
  end

  def ignore_duplicate_toggle
    duplicate_bike_group = DuplicateBikeGroup.find(params[:id])
    duplicate_bike_group.ignore = !duplicate_bike_group.ignore
    duplicate_bike_group.save
    flash[:success] = "Successfully marked #{duplicate_bike_group.segment} #{duplicate_bike_group.ignore ? "ignored" : "Un-ignored"}"
    redirect_back(fallback_location: root_url)
  end

  def destroy
    destroy_bike
  end

  def get_destroy
    if params[:id] == "multi_delete"
      bike_ids = defined?(params[:bikes_selected].keys) ? params[:bikes_selected].keys : params[:bikes_selected]
      if bike_ids.any?
        bike_ids.each do |id|
          Bike.unscoped.find(id).destroy!
          AfterBikeSaveWorker.perform_async(id)
        end
        # Lazy pluralize hack
        flash[:success] = "#{bike_ids.count} #{bike_ids.count == 1 ? "bike" : "bikes"} deleted!"
      else
        flash[:error] = "No bikes selected to delete!"
      end
      redirect_back(fallback_location: admin_bikes_url)
    else
      destroy_bike
    end
  end

  def show
    @active_tab = params[:active_tab]
    unless @active_tab.present?
      redirect_to edit_admin_bike_path
      nil
    end
  end

  def edit
    @recoveries = @bike.recovered_records
    @organizations = Organization.all
  end

  def update
    updator = BikeUpdator.new(user: current_user, bike: @bike, b_params: {bike: permitted_parameters}.as_json)
    updator.update_ownership
    updator.update_stolen_record
    if params[:mark_recovered_reason].present?
      @bike.current_stolen_record.add_recovery_information(
        recovered_description: params[:mark_recovered_reason],
        index_helped_recovery: params[:mark_recovered_we_helped],
        can_share_recovery: params[:can_share_recovery],
        recovering_user_id: current_user.id
      )
    end
    if @bike.update(permitted_parameters.except(:stolen_records_attributes))
      @bike.create_normalized_serial_segments
      return if return_to_if_present
      flash[:success] = "Bike was successfully updated."
      redirect_to(edit_admin_bike_url(@bike)) && return
    else
      render action: "edit"
    end
  end

  def unrecover
    stolen_record = StolenRecord.unscoped.where(bike_id: params[:bike_id],
      id: params[:stolen_record_id]).first
    if stolen_record.present?
      flash[:success] = "Marked unrecovered!"
      stolen_record.update(recovered_at: nil, current: true, recovery_link_token: nil)
    else
      flash[:error] = "Stolen record not found! Contact a developer"
    end
    redirect_to admin_bike_path(params[:bike_id])
  end

  helper_method :available_bikes

  protected

  def sortable_columns
    %w[id owner_email manufacturer_id updated_by_user_at]
  end

  def permitted_parameters
    params.require(:bike).permit(BikeCreator.old_attr_accessible + [bike_organization_ids: []])
  end

  def destroy_bike
    find_bike
    @bike.destroy
    AfterBikeSaveWorker.perform_async(@bike.id)
    flash[:success] = "Bike deleted!"
    redirect_to admin_bikes_url
  end

  def find_bike
    @bike = Bike.unscoped.find(params[:id])
  end

  def matching_bikes
    if params[:user_id].present?
      @user = User.username_friendly_find(params[:user_id])
      bikes = @user.bikes
    elsif params[:search_phone].present?
      bikes = Bike.search_phone(params[:search_phone])
    else
      # This unscopes, so it doesn't work with anything above
      bikes = Bike.unscoped
    end
    if params[:search_manufacturer].present?
      @manufacturer = Manufacturer.friendly_find(params[:search_manufacturer])
      bikes = if @manufacturer.present?
        bikes.where(manufacturer_id: @manufacturer&.id)
      else
        bikes.where(mnfg_name: params[:search_manufacturer])
      end
    end
    bikes = bikes.non_example if params[:search_example] == "non_example_only"
    if current_organization.present?
      bikes = if InputNormalizer.boolean(params[:search_only_creation_organization])
        bikes.includes(:ownerships).where(ownerships: {organization_id: current_organization.id})
      else
        bikes.organization(current_organization)
      end
    elsif params[:organization_id] == "false"
      # Have to include deleted_at or else we get nil
      bikes = bikes.includes(:ownerships).where(deleted_at: nil, ownerships: {organization_id: nil})
    end

    @motorized = InputNormalizer.boolean(params[:search_motorized])
    bikes = bikes.motorized if @motorized

    # Get a query error if both are passed
    if params[:search_email].present? && @user.blank?
      @search_email = params[:search_email]
      bikes = bikes.admin_text_search(@search_email)
    end

    if params[:serial].present?
      @serial_normalized = SerialNormalizer.normalized_and_corrected(params[:serial])
      bikes = bikes.matching_serial(@serial_normalized)
    end

    bikes = search_bike_statuses(bikes)

    @pos_search_type = %w[lightspeed_pos ascend_pos any_pos no_pos].include?(params[:search_pos]) ? params[:search_pos] : nil
    bikes = bikes.send(@pos_search_type) if @pos_search_type.present?
    @origin_search_type = Ownership.origins.include?(params[:search_origin]) ? params[:search_origin] : nil
    bikes = bikes.includes(:ownerships).where(ownerships: {origin: @origin_search_type}) if @origin_search_type.present?
    @multi_delete = InputNormalizer.boolean(params[:search_multi_delete])
    bikes
  end

  # Separated out purely to make logic easier to follow
  def search_bike_statuses(bikes)
    @searched_statuses = params.keys.select do |k|
      k.start_with?("search_status_") && InputNormalizer.boolean(params[k])
    end.map { |k| k.gsub(/\Asearch_status_/, "") }

    @searched_statuses = default_statuses if @searched_statuses.blank?
    @not_default_statuses = @searched_statuses != default_statuses

    if @searched_statuses.include?("example_only")
      bikes = bikes.where(example: true)
    elsif !@searched_statuses.include?("example")
      bikes = bikes.where(example: false)
    end

    if @searched_statuses.include?("spam_only")
      bikes = bikes.where(likely_spam: true)
    elsif !@searched_statuses.include?("spam")
      bikes = bikes.where(likely_spam: false)
    end

    if @searched_statuses.include?("deleted_only")
      bikes = bikes.where.not(deleted_at: nil)
    elsif !@searched_statuses.include?("deleted")
      bikes = bikes.where(deleted_at: nil)
    end

    bike_statuses = (%w[stolen with_owner abandoned impounded] & @searched_statuses)
      .map { |k| "status_#{k}" }
    if @searched_statuses.include?("unregistered_parking_notification")
      bike_statuses << "unregistered_parking_notification"
    end
    bikes.where(status: bike_statuses)
  end

  def default_statuses
    %w[stolen with_owner abandoned impounded unregistered_parking_notification] +
      (current_user.su_option?(:no_hide_spam) ? ["spam"] : [])
  end

  def available_bikes
    @available_bikes ||= matching_bikes.where(created_at: @time_range)
  end

  def missing_manufacturer_bikes
    session.delete(:missing_manufacturer_time_order) if params[:reset_view].present?
    if params[:search_time_ordered].present?
      session[:missing_manufacturer_time_order] = InputNormalizer.boolean(params[:search_time_ordered])
    end
    bikes = Bike.unscoped.where(manufacturer_id: Manufacturer.other.id).not_spam
    @motorized = InputNormalizer.boolean(params[:search_motorized])
    bikes = bikes.motorized if @motorized
    bikes = bikes.where("manufacturer_other ILIKE ?", "%#{params[:search_other_name]}%") if params[:search_other_name].present?
    bikes = bikes.where(created_at: @time_range) unless @period == "all"
    @include_blank = InputNormalizer.boolean(params[:search_include_blank])
    bikes = bikes.where.not(manufacturer_other: nil) unless @include_blank
    bikes = if session[:missing_manufacturer_time_order]
      bikes.order("created_at desc")
    else
      bikes.order(bikes.arel_table["manufacturer_other"].lower)
    end
    if current_organization.present?
      bikes = bikes.where(creation_organization_id: current_organization.id)
    elsif params[:search_exclude_organization_ids].present?
      @exclude_organizations = params[:search_exclude_organization_ids].split(",").map do |s|
        Organization.friendly_find(s)
      end.compact
      bikes = bikes.where.not(creation_organization_id: @exclude_organizations.map(&:id))
    end
    bikes
  end
end
