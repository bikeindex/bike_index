module Api
  module V1
    class UsersController < ApiV1Controller
      before_filter :bust_cache!, only: [:current]
      def default_serializer_options
        {
          root: false
        }
      end
      
      def current
        if current_user.present?
          respond_with current_user
        else
          respond_with user_present: false
        end
      end

      def request_serial_update
        new_serial = params[:serial_update_serial]
        bike_id = params[:serial_update_bike_id]
        reason = params[:serial_update_reason]
        if current_user.present? && new_serial.present? && bike_id.present? && reason.present?
          bike = Bike.find(bike_id)
          if bike.owner == current_user
            feedback = Feedback.new(email: current_user.email, body: reason, title: 'Serial update request', feedback_type: 'serial_update_request')
            feedback.name = (current_user.name.present? && current_user.name) || 'no name'
            feedback.feedback_hash = { bike_id: bike_id, new_serial: new_serial }
            feedback.save
            success = {success: 'submitted update'}
            render json: success and return
          end
        end        
        message = {errors: {not_allowed: 'nuh-uh'}}
        render json: message, status: 403
      end

      def send_request
        bike_id = params[:request_bike_id]
        reason = params[:request_reason]
        feedback_type = params[:request_type]
        if current_user.present? && reason.present? && bike_id.present? && feedback_type.present?
          bike = Bike.find(bike_id)
          if bike.owner == current_user
            feedback = Feedback.new(email: current_user.email, body: reason, title: "#{feedback_type.titleize}", feedback_type: feedback_type)
            feedback.name = (current_user.name.present? && current_user.name) || 'no name'
            feedback.feedback_hash = { bike_id: bike_id }
            if params[:did_we_help].present?
              feedback.feedback_hash[:did_we_help] = params[:did_we_help]
            end
            feedback.save
            success = {success: 'submitted request'}
            render json: success and return
          end
        end        
        message = {errors: {not_allowed: 'nuh-uh'}}
        render json: message, status: 403
      end

    end
  end
end 