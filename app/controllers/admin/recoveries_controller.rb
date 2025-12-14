class Admin::RecoveriesController < Admin::BaseController
  include SortableTable

  helper_method :available_recoveries

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @recoveries = pagy(available_recoveries.reorder("stolen_records.#{sort_column} #{sort_direction}")
      .includes(:bike), limit: @per_page, page: permitted_page)
  end

  def show
    redirect_to edit_admin_recovery_url
  end

  def edit
    @recovery ||= StolenRecord.unscoped.find(params[:id])
    @bike = Bike.unscoped.find_by_id(@recovery.bike_id)
  end

  def update
    @stolen_record = StolenRecord.unscoped.find(params[:id])
    @stolen_record.bike = Bike.unscoped.find_by_id(@stolen_record.bike_id)
    if params[:stolen_record][:mark_as_eligible].present?
      @stolen_record.recovery_display_status = "waiting_on_decision"
      redirect = new_admin_recovery_display_path(@stolen_record)
    elsif params[:stolen_record][:is_not_displayable].present?
      @stolen_record.recovery_display_status = "not_displayed"
    end

    if @stolen_record.update(permitted_parameters)
      flash[:success] = "Recovery Saved!"
      redirect_to redirect || admin_recoveries_url
    else
      @recovery = @stolen_record
      render action: :edit
    end
  end

  private

  def sortable_columns
    %w[recovered_at date_stolen created_at recovery_display_status]
  end

  def available_recoveries
    recoveries = StolenRecord.recovered

    if params[:search_recovery_display_status] == "all"
      @recovery_display_status = "all"
    else
      # Default to waiting_on_decision
      @recovery_display_status = params[:search_recovery_display_status]
      @recovery_display_status = "waiting_on_decision" unless StolenRecord.recovery_display_statuses.include?(@recovery_display_status)
      recoveries = recoveries.where(recovery_display_status: @recovery_display_status)
    end

    if Binxtils::InputNormalizer.boolean(params[:search_shareable])
      @shareable = true
      recoveries = recoveries.can_share_recovery
    end

    if Binxtils::InputNormalizer.boolean(params[:search_index_helped_recovery])
      @index_helped_recovery = true
      recoveries = recoveries.where(index_helped_recovery: true)
    end

    # We always render distance
    @distance = GeocodeHelper.permitted_distance(params[:search_distance], default_distance: 50)
    if params[:search_location].present?
      bounding_box = GeocodeHelper.bounding_box(params[:search_location], @distance)
      recoveries = recoveries.within_bounding_box(bounding_box)
    end

    if params[:search_displayed].present?
      recoveries = if params[:search_displayed] == "displayed"
        recoveries.with_recovery_display
      else
        recoveries.without_recovery_display
      end
    end

    @time_range_column = sort_column if %w[date_stolen created_at].include?(sort_column)
    @time_range_column ||= "recovered_at"
    recoveries.where(@time_range_column => @time_range)
  end

  def permitted_parameters
    params.require(:stolen_record).permit(BikeServices::StolenRecordUpdator.old_attr_accessible)
  end
end
