module Bikes
  class RecoveredController < Bikes::BaseController
    # The theft alert email's recovery link marks the bike recovered without signing in -
    # Bikes::RecoveryController#update parks the bike in the session, which stands in for being the owner
    skip_before_action :ensure_user_allowed_to_edit, if: :recovered_from_link?

    def show
      stolen_record = StolenRecord.recovered.where.not(recovered_at: nil).order(recovered_at: :desc).find_by(bike_id: @bike.id)
      return redirect_to(bike_path(@bike)) if stolen_record.blank? || @bike.status_stolen?

      @page_title = translation(:recovered, bike_type: @bike.type)
      render Pages::Bikes::Recovered::Show::Component.new(bike: @bike, stolen_record:)
    end

    private

    def recovered_from_link? = session[:recovered_bike_id] == @bike&.id
  end
end
