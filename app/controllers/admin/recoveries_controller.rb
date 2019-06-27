class Admin::RecoveriesController < Admin::BaseController
  include SortableTable
  layout "new_admin"

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @recoveries = matching_recoveries.reorder("stolen_records.#{sort_column} #{sort_direction}")
                                     .page(page).per(per_page)
  end

  def show
    redirect_to edit_admin_recovery_url
  end

  def edit
    @recovery = StolenRecord.unscoped.find(params[:id])
    @bike = @recovery.bike.decorate if @recovery.bike.present?
  end

  def update
    @stolen_record = StolenRecord.unscoped.find(params[:id])
    if params[:stolen_record][:mark_as_eligible].present?
      @stolen_record.recovery_display_status = "waiting_on_decision"
      redirect = new_admin_recovery_display_path(@stolen_record)
    elsif params[:stolen_record][:is_not_displayable].present?
      @stolen_record.recovery_display_status = "not_displayed"
    end
    if @stolen_record.update_attributes(permitted_parameters)
      flash[:success] = "Recovery Saved!"
      redirect_to redirect ||= admin_recoveries_url
    else
      raise StandardError
      render action: :edit
    end
  end

  helper_method :recovery_display_status_searched

  private

  def sortable_columns
    %w[date_recovered recovery_display_status]
  end

  def recovery_display_status_searched
    return StolenRecord::RECOVERY_DISPLAY_STATUS_ENUM.values if params[:search_recovery_display_status] == "all"
    # Legacy enum issue so excited for TODO: Rails 5 update
    recovery_display_status_parameter = (params[:search_recovery_display_status] || "waiting_on_decision").to_sym
    StolenRecord::RECOVERY_DISPLAY_STATUS_ENUM[recovery_display_status_parameter.to_sym] || 1
  end

  def matching_recoveries
    recoveries = StolenRecord.recovered.where(recovery_display_status: recovery_display_status_searched)
    recoveries.includes(:bike)
  end

  def permitted_parameters
    params.require(:stolen_record).permit(StolenRecord.old_attr_accessible)
  end
end
