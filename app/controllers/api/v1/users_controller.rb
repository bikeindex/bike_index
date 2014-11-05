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
            if params[:serial_update_serial].present?
              feedback.feedback_hash[:new_serial] = params[:serial_update_serial]
              feedback.feedback_hash[:old_serial] = bike.serial_number
              bike.serial_number = params[:serial_update_serial]
              bike.save
              SerialNormalizer.new({serial: params[:serial_update_serial]}).save_segments(bike.id)
            elsif params[:manufacturer_update_manufacturer].present?
              feedback.feedback_hash[:old_manufacturer] = bike.manufacturer.name
              if bike.manufacturer_other.present?
                feedback.feedback_hash[:old_manufacturer] += " (#{bike.manufacturer_other})"
                bike.manufacturer_other = nil
              end
              bike.manufacturer_id = params[:manufacturer_update_manufacturer]
              bike.save
              feedback.feedback_hash[:new_manufacturer] = bike.manufacturer.name
            elsif feedback_type.match('bike_recovery')
              if bike.current_stolen_record.present?
                RecoveryUpdateWorker.perform_async(bike.current_stolen_record.id, params)
                if params[:index_helped_recovery].present?
                  feedback.feedback_hash[:index_helped_recovery] = params[:index_helped_recovery]
                end
                if params[:can_share_recovery].present?
                  feedback.feedback_hash[:can_share_recovery] = params[:can_share_recovery]
                else
                  RecoveryNotifyWorker.perform_in(30.minutes, bike.current_stolen_record.id)
                end
              end
            end
            feedback.save
            success = {success: 'submitted request'}
            render json: success and return
          end
        end        
        message = {errors: {not_allowed: 'nuh-uh'}}
        render json: message, status: 403
      end
      
      def bust_cache!
        response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "#{1.year.ago}"
      end

    end
  end
end 