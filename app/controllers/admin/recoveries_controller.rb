module Admin
  class RecoveriesController < Admin::BaseController
    include Binxtils::SortableTable

    # Each needs the ability its single-record action does
    BULK_ACTIONS = {
      "display" => {done: "displayed", ability: {controller_name: "recovery_displays", action_name: "create"}},
      "not_displayed" => {done: "marked not displayable", ability: {controller_name: "recoveries", action_name: "update"}}
    }.freeze

    helper_method :available_recoveries

    def index
      @per_page = permitted_per_page(default: 50)
      @pagy, @recoveries = pagy(:countish, available_recoveries.reorder(sortable_order(StolenRecord))
        .includes(:bike, :country, :region_record, :recovery_display, :recovering_user), limit: @per_page, page: permitted_page)
    end

    def bulk_update
      selected = params[:sr_selected].respond_to?(:keys) ? params[:sr_selected].keys : Array(params[:sr_selected])
      recoveries = StolenRecord.recovered.waiting_on_decision.where(id: selected).to_a
      bulk_action = BULK_ACTIONS[params[:bulk_action]]
      if recoveries.none?
        flash[:error] = "No recoveries waiting on a decision selected!"
      elsif bulk_action
        count = send(:"bulk_#{params[:bulk_action]}", recoveries)
        flash[:success] = "#{count} #{"recovery".pluralize(count)} #{bulk_action[:done]}"
      else
        flash[:error] = "Unknown action!"
      end
      redirect_back(fallback_location: admin_recoveries_url)
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
        render action: :edit, status: :unprocessable_entity
      end
    end

    private

    def require_index_admin!
      ability = BULK_ACTIONS.dig(params[:bulk_action], :ability) if action_name == "bulk_update"
      ability ? super(**ability) : super
    end

    # Each returns how many it changed
    def bulk_display(recoveries)
      displays = recoveries.map { build_recovery_display(it) }
      failed = displays.reject(&:save)
      flash[:error] = "Unable to display: #{failed.map { "##{it.stolen_record_id} #{it.errors.full_messages.to_sentence}" }.join("; ")}" if failed.any?
      displays.size - failed.size
    end

    def bulk_not_displayed(recoveries)
      recoveries.count { it.update(recovery_display_status: "not_displayed") }
    end

    # Edits go to the display, not the recovery, which keeps what the owner wrote
    def build_recovery_display(stolen_record)
      edits = params.fetch(:display, {}).fetch(stolen_record.id.to_s, {}).permit(:quote, :quote_by, :location_string)
      bike = Bike.unscoped.find_by_id(stolen_record.bike_id)
      RecoveryDisplay.new(RecoveryDisplay.attributes_from_stolen_record(stolen_record, bike:)
        .merge(edits.to_h.symbolize_keys, remote_photo_url: bike&.image_url))
    end

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
      recoveries.unscope(:order).where("stolen_records.#{@time_range_column}" => @time_range)
    end

    def permitted_parameters
      params.require(:stolen_record).permit(BikeServices::StolenRecordUpdator.old_attr_accessible)
    end
  end
end
