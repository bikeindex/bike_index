module API
  module V1
    class NotificationsController < APIV1Controller
      before_action :authenticate_notification_permission
      skip_before_action :verify_authenticity_token

      def create
        bike = Bike.find(params[:notification_hash][:bike_id])
        if params[:notification_hash][:notification_type].to_s.match("stolen_twitter_alerter").present?
          if bike.fetch_current_stolen_record.present?
            customer_contact = CustomerContact.new(body: "EMPTY",
              bike_id: bike.id,
              kind: :stolen_twitter_alerter,
              title: title_tag(bike),
              user_email: bike.owner_email,
              creator_email: "bryan@bikeindex.org",
              info_hash: params[:notification_hash])
            if customer_contact.save
              render(json: {success: true}) && return
            else
              msg = customer_contact.errors.full_messages.to_sentence
              render(json: {error: msg}, status: :unprocessable_entity) && return
            end
          end
        end
        render(json: {error: "Unable to send that email, srys"}, status: :unprocessable_entity) && return
      end

      def authenticate_notification_permission
        unless params[:access_token] == ENV["NOTIFICATIONS_API_KEY"]
          render(json: "Not authorized", status: :unauthorized) && return
        end
      end

      def title_tag(bike)
        if bike.status_abandoned?
          "We tweeted about the bike you found!"
        else
          "We tweeted about your stolen bike!"
        end
      end
    end
  end
end
