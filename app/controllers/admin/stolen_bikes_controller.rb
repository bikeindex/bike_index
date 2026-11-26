module Admin
  class StolenBikesController < Admin::BaseController
    include Binxtils::SortableTable

    # Each needs the ability its single-record action does
    BULK_ACTIONS = {
      "approve" => {done: "approved", ability: {controller_name: "stolen_bikes", action_name: "approve"}},
      "spam" => {done: "marked spam", ability: {controller_name: "bikes", action_name: "update"}},
      "delete" => {done: "deleted", ability: {controller_name: "bikes", action_name: "destroy"}}
    }.freeze

    before_action :find_bike, only: %i[edit update]
    helper_method :available_stolen_records

    def index
      @per_page = permitted_per_page(default: 50)
      @pagy, @stolen_records = pagy(:countish, available_stolen_records.includes(:country, :region_record)
        .reorder(sortable_order(StolenRecord)), limit: @per_page, page: permitted_page)
    end

    def approve
      find_bike
      @bike.current_stolen_record.update_attribute :approved, true
      BikeJobs::ApproveStolenListingJob.perform_async(@bike.id)
      flash[:success] = "Stolen Bike was approved"
      redirect_to edit_admin_stolen_bike_url(@bike)
    end

    def bulk_update
      stolen_records = StolenRecord.unscoped.where(id: selected_ids(:sr_selected))
      if stolen_records.none?
        flash[:error] = "No stolen records selected!"
      elsif BULK_ACTIONS.include?(params[:bulk_action])
        count = send(:"bulk_#{params[:bulk_action]}", stolen_records)
        flash[:success] = "#{count} stolen #{"bike".pluralize(count)} #{BULK_ACTIONS.dig(params[:bulk_action], :done)}"
      else
        flash[:error] = "Unknown action!"
      end
      redirect_back(fallback_location: admin_stolen_bikes_url)
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
        flash[:error] = "Unknown update action! Please let Seth know where you encountered this!"
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
      if Binxtils::InputNormalizer.boolean(params[:stolen_record_id])
        @stolen_record = StolenRecord.unscoped.find(params[:id])
        @bike = Bike.unscoped.find_by_id(@stolen_record.bike_id)
      else
        @bike = Bike.unscoped.find(params[:id])
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
      BikeJobs::AfterStolenRecordSaveJob.perform_async(@bike.current_stolen_record_id, true,
        selected_image&.id)
      # Lazy hack to wait for it to process
      sleep 1
      flash[:success] ||= "Promoted alert bike image updated."
    end

    def available_stolen_records
      return @available_stolen_records if defined?(@available_stolen_records)

      @unapproved_only = !Binxtils::InputNormalizer.boolean(params[:search_unapproved])
      @only_without_location = Binxtils::InputNormalizer.boolean(params[:search_without_location])
      if @unapproved_only
        available_stolen_records = StolenRecord.current.unapproved
        if @only_without_location
          available_stolen_records = available_stolen_records.without_location
        else
          @unapproved_without_location_count = available_stolen_records.without_location.count
          available_stolen_records = available_stolen_records.with_location
        end
      else
        available_stolen_records = StolenRecord
      end
      unless Binxtils::InputNormalizer.boolean(params[:search_include_spam])
        available_stolen_records = available_stolen_records.not_spam
      end

      @with_promoted_alert = Binxtils::InputNormalizer.boolean(params[:search_with_promoted_alert])
      if @with_promoted_alert
        available_stolen_records = available_stolen_records.with_theft_alerts_paid_or_admin
      end

      @time_range_column = sort_column if %w[date_stolen].include?(sort_column)
      @time_range_column ||= "created_at"
      @available_stolen_records = available_stolen_records.where(@time_range_column => @time_range)
    end

    private

    # Each returns how many it changed
    def bulk_approve(stolen_records)
      stolen_records.each { it.update_attribute :approved, true }
      BikeJobs::ApproveStolenListingJob.perform_bulk(stolen_records.map { [it.bike_id] })
      stolen_records.size
    end

    def bulk_spam(stolen_records)
      bikes = Bike.unscoped.where(id: stolen_records.select(:bike_id)).to_a
      failed = bikes.reject { it.update(likely_spam: true) }
      flash[:error] = "Unable to mark spam: #{failed.map { "##{it.id}" }.join(", ")}" if failed.any?
      bikes.size - failed.size
    end

    # Inline, like admin/bikes#destroy, so the redirect doesn't list them still
    def bulk_delete(stolen_records)
      bike_ids = stolen_records.distinct.pluck(:bike_id)
      bike_ids.each { BikeJobs::BikeDeleterJob.new.perform(it, false, current_user.id) }
      bike_ids.size
    end
  end
end
