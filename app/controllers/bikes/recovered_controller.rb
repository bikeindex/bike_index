module Bikes
  class RecoveredController < Bikes::BaseController
    # The theft alert email's recovery link marks the bike recovered without signing in - it parks its
    # token in the session (Bikes::RecoveryController#edit), which stands in for being the owner here
    skip_before_action :ensure_user_allowed_to_edit, if: :recovery_link?
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
        user: current_user, email: (@bike.owner_email unless current_user), name: ("no name" unless current_user&.name.present?),
        feedback_hash: {bike_id: @bike.id, index_helped_recovery: recovery_params[:index_helped_recovery],
                        can_share_recovery: recovery_params[:can_share_recovery]})
      stolen_record.add_recovery_information(recovery_params.slice(:recovered_at, :timezone, :index_helped_recovery,
        :can_share_recovery).merge(recovered_description:, recovering_user_id: current_user&.id))
      if session.delete(:recovery_link_token).present?
        EmailJobs::RecoveredFromLinkJob.perform_async(stolen_record.id)
        session[:recovered_bike_id] = @bike.id
      end
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
      render Pages::Bikes::Recovered::New::Component.new(bike: @bike, submitted:,
        back_path: recovery_link? ? bike_path(@bike) : bike_stolen_report_path(@bike)), status:
    end

    # The link's token for this bike's theft, or - once it's spent - the recovery it made
    def recovery_link?
      return @recovery_link if defined?(@recovery_link)

      @recovery_link = if action_name == "show"
        session[:recovered_bike_id] == @bike.id
      else
        !!StolenRecord.find_matching_token(bike_id: @bike.id, recovery_link_token: session[:recovery_link_token])&.current?
      end
    end
  end
end
