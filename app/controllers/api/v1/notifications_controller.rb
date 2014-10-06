module Api
  module V1
    class NotificationsController < ApiV1Controller
      before_filter :authenticate_notification_permission
      skip_before_filter  :verify_authenticity_token

      def create
        bike = Bike.find(params[:notification_hash][:bike_id])
        if params[:notification_hash][:notification_type].to_s.match('stolen_twitter_alerter').present?
          if bike.find_current_stolen_record.present?
            customer_contact = CustomerContact.new(body: 'EMPTY',
              bike_id: bike.id,
              contact_type: 'stolen_twitter_alerter',
              title: "We tweeted about your stolen bike!",
              user_email: bike.owner_email,
              creator_email: 'bryan@bikeindex.org',
              info_hash: params[:notification_hash])
            if customer_contact.save
              Resque.enqueue(StolenBikeAlertEmailJob, customer_contact.id)
              render json: { success: true } and return
            else
              msg = customer_contact.errors.full_messages.to_sentence
              render json: {error: msg}, status: :unprocessable_entity and return
            end
          end
        end
        render json: {error: "Unable to send that email, srys"}, status: :unprocessable_entity and return
      end
    
      def authenticate_notification_permission
        unless params[:access_token] == ENV['NOTIFICATIONS_API_KEY']
          render json: "Not authorized", status: :unauthorized and return
        end
      end

    end

  end
end