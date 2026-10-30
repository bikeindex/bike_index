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
      @pagy, @recoveries = pagy(:countish, available_recoveries.reorder(sortable_order(StolenRecord)), limit: @per_page, page: permitted_page)
    end

    def bulk_update
      recoveries = StolenRecord.recovered.waiting_on_decision.where(id: selected_ids(:sr_selected)).to_a
      bulk_action = BULK_ACTIONS[params[:bulk_action]]
      if recoveries.none?
        flash[:error] = "No recoveries waiting on a decision selected!"
      elsif bulk_action
        count = send(:"bulk_#{params[:bulk_action]}", recoveries)
        flash[:success] = "#{count} #{"recovery".pluralize(count)} #{bulk_action[:done]}" if count.positive?
      else
        flash[:error] = "Unknown action!"
      end
      return redirect_back(fallback_location: admin_recoveries_url) if @failed_edits.blank?

      # Rendered rather than redirected, so the failed rows keep what the admin typed
      flash.discard
      set_period
      index
      render :index, status: :unprocessable_entity
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

    # Each returns how many it changed
    def bulk_display(recoveries)
      errors = bulk_errors("display", recoveries) { display_error(it) }
      @failed_edits = errors.keys.index_with { display_edits(it) } if errors.any?
      recoveries.size - errors.size
    end

    def bulk_not_displayed(recoveries)
      recoveries.size - bulk_errors("mark not displayable", recoveries) { not_displayed_error(it) }.size
    end

    # The lock makes a concurrent submit wait, then see what it did. Returns {id => error}
    def bulk_errors(verb, recoveries)
      errors = recoveries.to_h { |stolen_record| [stolen_record.id, stolen_record.with_lock { yield stolen_record }] }.compact
      flash[:error] = "Unable to #{verb}: #{errors.map { |id, error| "##{id} #{error}" }.join("; ")}" if errors.any?
      errors
    end

    # Edits go to the display, not the recovery, which keeps what the owner wrote
    def display_error(stolen_record)
      bike = Bike.unscoped.find_by_id(stolen_record.bike_id)
      return "bike is hidden" if bike.present? && !bike.current?

      decided = decided_error(stolen_record)
      return decided if decided

      attributes = RecoveryDisplay.attributes_from_stolen_record(stolen_record, bike:).merge(display_edits(stolen_record.id))
      recovery_display = RecoveryDisplay.new(attributes.merge(remote_photo_url: bike&.image_url))
      recovery_display.errors.full_messages.to_sentence unless recovery_display.save
    end

    def not_displayed_error(stolen_record)
      decided_error(stolen_record) ||
        (stolen_record.errors.full_messages.to_sentence unless stolen_record.update(recovery_display_status: "not_displayed"))
    end

    def decided_error(stolen_record)
      return "is already displayed" if RecoveryDisplay.unscoped.exists?(stolen_record_id: stolen_record.id)

      "is #{stolen_record.recovery_display_status.humanize(capitalize: false)}" unless stolen_record.waiting_on_decision?
    end

    def display_edits(stolen_record_id)
      params.fetch(:display, {}).fetch(stolen_record_id.to_s, {}).permit(:quote, :quote_by, :location_string).to_h.symbolize_keys
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
