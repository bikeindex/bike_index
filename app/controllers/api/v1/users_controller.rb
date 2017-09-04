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
              bike.current_stolen_record.update_attribute :tsved_at, nil if bike.current_stolen_record.present?
              feedback.feedback_hash[:new_serial] = params[:serial_update_serial]
              feedback.feedback_hash[:old_serial] = bike.serial_number
              bike.serial_number = params[:serial_update_serial]
              bike.save
              bike.create_normalized_serial_segments
            elsif params[:manufacturer_update_manufacturer].present?
              feedback.feedback_hash[:old_manufacturer] = bike.manufacturer.name
              if bike.manufacturer_other.present?
                feedback.feedback_hash[:old_manufacturer] += " (#{bike.manufacturer_other})"
                bike.manufacturer_other = nil
              end
              bike.manufacturer_id = Manufacturer.friendly_id_find(params[:manufacturer_update_manufacturer])
              if bike.manufacturer_id.present?
                bike.save
                feedback.feedback_hash[:new_manufacturer] = bike.manufacturer.name
              end
            elsif feedback_type.match('bike_recovery')
              recover_bike(bike, feedback)
            end
            feedback.save
            success = { success: 'submitted request' }
            render json: success and return
          end
        end
        message = { errors: { not_allowed: 'nuh-uh' } }
        render json: message, status: 403
      end

      def bust_cache!
        response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "#{1.year.ago}"
      end

      private

      def recover_bike(bike, feedback)
        return true unless bike.current_stolen_record.present?
        feedback.feedback_hash.merge!(index_helped_recovery: params[:index_helped_recovery],
                                      can_share_recovery: params[:can_share_recovery])

        bike.current_stolen_record.add_recovery_information(
          params.merge(recovered_description: feedback.body)
        )
      end
    end
  end
end