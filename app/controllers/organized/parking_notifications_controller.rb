module Organized
  class ParkingNotificationController < Organized::BaseController
    before_action :ensure_access_to_abandoned_bikes!, only: %i[index create]

    def index
      members =
        current_organization
          .users
          .map { |u| u && [u.id.to_s, { name: u.display_name }] }
          .compact
          .to_h

      @page_data = {
        google_maps_key: ENV["GOOGLE_MAPS"],
        map_center_lat: current_organization.map_focus_coordinates[:latitude],
        map_center_lng: current_organization.map_focus_coordinates[:longitude],
        members: members,
        root_path: organization_parking_notifications_path(organization_id: current_organization.to_param),
      }

      respond_to do |format|
        format.html
        format.json do
          render json: matching_parking_notifications.reorder(created_at: :desc),
                 root: "parking_notifications",
                 each_serializer: ParkingNotificationSerializer
        end
      end
    end

    def show
      @parking_notification = parking_notifications.find(params[:id])
      @bike = @parking_notification.bike
    end

    def create
      @parking_notification = ParkingNotification.new(permitted_parameters)
      if @parking_notification.save
        flash[:success] = translation(:parking_notificationed, bike_type: @parking_notification.bike.type)
      else
        flash[:error] = translation(:unable_to_record, errors: @parking_notification.errors.full_messages.to_sentence)
      end
       redirect_back(fallback_location: organization_parking_notifications_path(organization_id: current_organization.to_param))
    end

    helper_method :matching_parking_notifications, :search_params_present?

    private

    def parking_notifications
      current_organization.parking_notifications
    end

    def matching_parking_notifications
      return @matching_parking_notifications if defined?(@matching_parking_notifications)
      @matching_parking_notifications = parking_notifications
      if params[:search_bike_id].present?
        @matching_parking_notifications = @matching_parking_notifications.where(bike_id: params[:search_bike_id])
      end
      @matching_parking_notifications
    end

    def search_params_present?
      # Eventually, will check period select, etc
      (params.keys & %w[search_bike_id]).any?
    end

    def permitted_parameters
      params.require(:parking_notification).permit(:notes, :bike_id, :latitude, :longitude, :accuracy, :kind)
            .merge(user_id: current_user.id, organization_id: current_organization.id)
    end

    def ensure_access_to_abandoned_bikes!
      return true if current_organization.paid_for?("abandoned_bikes")
      flash[:error] = translation(:your_org_does_not_have_access)
      redirect_to organization_bikes_path(organization_id: current_organization.to_param)
      return
    end
  end
end
