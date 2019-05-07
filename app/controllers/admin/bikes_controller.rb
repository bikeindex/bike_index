class Admin::BikesController < Admin::BaseController
  include SortableTable
  before_filter :find_bike, only: [:edit, :destroy, :update, :get_destroy]
  before_action :set_period, only: [:index]

  def index
    @page = params[:page] || 1
    per_page = params[:per_page] || 100
    @render_chart = ActiveRecord::Type::Boolean.new.type_cast_from_database(params[:render_chart])
    @bikes = matching_bikes.includes(:creation_organization, :creation_states, :paint).reorder("bikes.#{sort_column} #{sort_direction}").page(@page).per(per_page)
    render layout: "new_admin"
  end

  def missing_manufacturer
    session.delete(:missing_manufacturer_time_order) if params[:reset_view].present?
    session[:missing_manufacturer_time_order] = ActiveRecord::Type::Boolean.new.type_cast_from_database(params[:time_ordered]) if params[:time_ordered].present?
    bikes = Bike.unscoped.where(manufacturer_id: Manufacturer.other.id)
    bikes = session[:missing_manufacturer_time_order] ? bikes.order("created_at desc") : bikes.order("manufacturer_other ASC")
    page = params[:page] || 1
    per_page = params[:per_page] || 100
    @bikes = bikes.page(page).per(per_page)
    render layout: "new_admin"
  end

  def update_manufacturers
    if params[:manufacturer_id].present? && params[:bikes_selected].present?
      manufacturer_id = params[:manufacturer_id]
      params[:bikes_selected].keys.each do |bid|
        Bike.find(bid).update_attributes(manufacturer_id: manufacturer_id, manufacturer_other: nil)
      end
      flash[:success] = "Success. Bikes updated"
      redirect_to :back and return
    end
    flash[:notice] = "Sorry, you need to add bikes and a manufacturer"
    redirect_to :back
  end

  def duplicates
    if params[:show_ignored]
      duplicate_groups = DuplicateBikeGroup.order("created_at desc")
    else
      duplicate_groups = DuplicateBikeGroup.unignored.order("created_at desc")
    end
    @page = params[:page] || 1
    per_page = params[:per_page] || 25
    @duplicate_groups = duplicate_groups.page(@page).per(per_page)
    render layout: "new_admin"
  end

  def ignore_duplicate_toggle
    duplicate_bike_group = DuplicateBikeGroup.find(params[:id])
    duplicate_bike_group.ignore = !duplicate_bike_group.ignore
    duplicate_bike_group.save
    flash[:success] = "Successfully marked #{duplicate_bike_group.segment} #{duplicate_bike_group.ignore ? "ignored" : "Un-ignored"}"
    redirect_to :back
  end

  def destroy
    destroy_bike
  end

  def get_destroy
    destroy_bike
  end

  def show
    redirect_to edit_admin_bike_url
  end

  def edit
    @bike = @bike.decorate
    @fast_attr_update = params[:fast_attr_update]
    @recoveries = @bike.recovered_records
    @organizations = Organization.all
    render layout: "new_admin"
  end

  def update
    @fast_attr_update = params.delete(:fast_attr_update)
    updator = BikeUpdator.new(user: current_user, bike: @bike, b_params: { bike: permitted_parameters }.as_json)
    updator.update_ownership
    updator.update_stolen_record
    @bike = @bike.decorate
    if params[:mark_recovered_reason].present?
      @bike.current_stolen_record.add_recovery_information(
        recovered_description: params[:mark_recovered_reason],
        index_helped_recovery: params[:mark_recovered_we_helped],
        can_share_recovery: params[:can_share_recovery],
      )
    end
    if @bike.update_attributes(permitted_parameters.except(:stolen_records_attributes))
      @bike.create_normalized_serial_segments
      return if return_to_if_present
      flash[:success] = "Bike was successfully updated."
      if @fast_attr_update.present? && @fast_attr_update
        redirect_to edit_admin_bike_url(@bike, fast_attr_update: true) and return
      else
        redirect_to edit_admin_bike_url(@bike) and return
      end
    else
      render action: "edit", layout: "new_admin"
    end
  end

  def unrecover
    stolen_record = StolenRecord.unscoped.where(bike_id: params[:bike_id],
                                                id: params[:stolen_record_id]).first
    if stolen_record.present?
      bike = Bike.unscoped.find(params[:bike_id])
      flash[:success] = "Marked unrecovered!"
      stolen_record.update_attributes(date_recovered: nil, current: true, recovery_link_token: nil)
      bike.update_attribute :stolen, true
    else
      flash[:error] = "Stolen record not found! Contact a developer"
    end
    redirect_to admin_bike_path(params[:bike_id])
  end

  helper_method :available_bikes

  protected

  def sortable_columns
    %w[id owner_email manufacturer_id]
  end

  def permitted_parameters
    params.require(:bike).permit(Bike.old_attr_accessible + [bike_organization_ids: []])
  end

  def destroy_bike
    @bike.destroy
    AfterBikeSaveWorker.perform_async(@bike.id)
    flash[:success] = "Bike deleted!"
    if params[:multi_delete]
      redirect_to admin_root_url
      # redirect_to admin_bikes_url(page: params[:multi_delete], multi_delete: 1)
    else
      redirect_to admin_bikes_url
    end
  end

  def find_bike
    @bike = Bike.unscoped.find(params[:id])
  end

  def matching_bikes
    return @matching_bikes if defined?(@matching_bikes)
    bikes = Bike.unscoped
    # do example up here because it unscopes
    bikes = bikes.example if params[:search_example].present?
    bikes = bikes.non_example if params[:search_non_example].present?
    bikes = bikes.organization(current_organization) if current_organization.present?
    bikes = bikes.admin_text_search(params[:search_email]) if params[:search_email].present?
    bikes = bikes.stolen if params[:search_stolen].present?
    @pos_search_type = %w[lightspeed_pos ascend_pos any_pos not_pos].include?(params[:search_pos]) ? params[:search_pos] : nil
    bikes = bikes.send(@pos_search_type) if @pos_search_type.present?
    bikes = bikes.ascend_pos if params[:search_ascend].present?
    bikes = bikes.lightspeed_pos if params[:search_lightspeed].present?
    @matching_bikes = bikes
  end

  def available_bikes
    matching_bikes.where(created_at: @time_range)
  end
end
