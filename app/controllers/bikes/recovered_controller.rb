module Bikes
  class RecoveredController < Bikes::BaseController
    # A component renders as whatever the request asks for - a Turbo submission that redirects here asks for a stream
    before_action :force_html_response

    def new
      return redirect_to(bike_path(@bike)) unless @bike.status_stolen?

      render_form
    end

    def create
      stolen_record = @bike.current_stolen_record
      return redirect_to(bike_path(@bike)) if stolen_record.blank?
      return render_form(submitted: recovery_params, status: :unprocessable_entity) if recovery_params[:story].blank?

      recovered_description = recovery_params.values_at(:how, :story).compact_blank.join(": ")
      Feedback.create(feedback_type: "bike_recovery", title: "Bike Recovery", body: recovered_description,
        email: current_user.email, name: current_user.name.presence || "no name", user_id: current_user.id,
        feedback_hash: {bike_id: @bike.id, index_helped_recovery: recovery_params[:index_helped_recovery],
                        can_share_recovery: recovery_params[:can_share_recovery]})
      stolen_record.add_recovery_information(recovery_params.slice(:recovered_at, :timezone, :index_helped_recovery,
        :can_share_recovery).merge(recovered_description:, recovering_user_id: current_user.id))
      redirect_to bike_recovered_path(@bike)
    end

    def show
      stolen_record = StolenRecord.recovered_ordered.find_by(bike_id: @bike.id)
      return redirect_to(bike_path(@bike)) if stolen_record.blank? || @bike.status_stolen?

      @page_title = translation(:recovered, bike_type: @bike.type)
      render Pages::Bikes::Recovered::Show::Component.new(bike: @bike, stolen_record:)
    end

    private

    def recovery_params
      params.fetch(:recovery, {}).permit(:how, :story, :recovered_at, :timezone, :index_helped_recovery, :can_share_recovery)
    end

    def render_form(submitted: {}, status: :ok)
      @page_title = translation(:mark_recovered, bike_type: @bike.type, controller_method: :new)
      render Pages::Bikes::Recovered::New::Component.new(bike: @bike, submitted:), status:
    end
  end
end
