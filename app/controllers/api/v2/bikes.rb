CYCLE_TYPE_SLUGS = !!CycleType && CycleType.slugs rescue ['bike']
COLOR_NAMES = !!Color && Color.pluck(:name) rescue []
module API
  module V2
    class Bikes < API::V2::Root
      include API::V2::Defaults

      helpers do
        params :bike_attrs do           
          optional :rear_wheel_bsd, type: Integer, desc: "rear_wheel_bsd"
          optional :rear_tire_narrow, type: Boolean, desc: "boolean. Is it a skinny tire?"
          optional :rear_wheel_bsd, type: String, desc: "Copies `rear_wheel_bsd` if not set"
          optional :rear_tire_narrow, type: Boolean, desc: "Copies `rear_tire_narrow` if not set"
          optional :frame_model, type: String, desc: "What frame model?"
          optional :year, type: Integer, desc: "What year was the frame made?"
          optional :description, type: String, desc: "General description"
          
          optional :primary_frame_color, type: String, values: COLOR_NAMES, desc: "Main color of frame"
          optional :secondary_frame_color, type: String, values: COLOR_NAMES, desc: "Secondary color"
          optional :tertiary_frame_color, type: String, values: COLOR_NAMES, desc: "Third color"
        end


        # group :stolen do 
        #   optional :phone, type: String, desc: "Owner's phone number"
        #   optional :city, type: String, desc: "Where the bike was stolen"
        #   optional :country, type: String, desc: "Where the bike was stolen"
        #   optional :zipcode, type: String, desc: "Where the bike was stolen"
        #   optional :state, type: String, desc: "Where the bike was stolen"
        #   optional :address, type: String, desc: "Where the bike was stolen"
        #   optional :date_stolen, type: Integer, desc: "When was the bike stolen"
        #   # all_or_none_of :phone, :city, :country, :zipcode, :date_stolen
        # end
        # optional :components, type: Array do
        #   requires :manufacturer, type: String, desc: "Manufacturer name or ID"
        #   # [Manufacturer name or ID](api_v2#!/manufacturers/GET_version_manufacturers_format)
        #   requires :ctype
        # end

        def find_bike
          @bike = Bike.unscoped.find(params[:id])
        end

        def authorize_bike_for_user(addendum='')
          return true if @bike.owner == current_user
          @bike.current_ownership.can_be_claimed_by(current_user)
          if @bike.current_ownership.can_be_claimed_by(current_user)
            @bike.current_ownership.mark_claimed
            return true
          end  
          error!("You do not own that #{@bike.type}#{addendum}", 403) 
        end

      end

      resource :bikes do
        desc "View bike with a given ID" 
        params do
          requires :id, type: Integer, desc: 'Bike id'
        end
        get ':id', serializer: BikeV2ShowSerializer, root:  'bike' do 
          find_bike
        end


        desc "Add a bike to the Index!", {
          notes: <<-NOTE
            **Requires** `write_bikes` **in the access token** you use to create the bike.

            <hr> 

            **Creating test bikes**: To create test bikes, set `test` to true. These bikes:

            - Do not show turn up in searches
            - Do not send an email to the owner on creation
            - Are automatically deleted after a few days
            - Can be viewed in the API /v2/bikes/{id} (same as non-test bikes)
            - Can be viewed on the HTML site /bikes/{id} (same as non-test bikes)

            *`test` is automatically marked true on this documentation page. Set it to false it if you want to create actual bikes*

            **Ownership**: Bikes you create will be created by the user token you authenticate with, but they will be sent to the email address you specify.
          NOTE
        }
        params do
          requires :serial, type: String, desc: "The serial number for the bike"
          requires :manufacturer, type: String, desc: "Manufacturer name or ID"
          # [Manufacturer name or ID](api_v2#!/manufacturers/GET_version_manufacturers_format)
          requires :owner_email, type: String, desc: "Owner email"
          requires :color, type: String, desc: "Main color or paint - does not have to be one of the accepted colors"
          optional :test, type: Boolean, desc: "Is this a test bike?"
          optional :organization_slug, type: String, desc: "Organization bike should be created by. **Only works** if user is a member of the organization"
          optional :cycle_type_slug, type: String, values: CYCLE_TYPE_SLUGS, default: 'bike', desc: "Type of cycle"

          use :bike_attrs 
        end
        post '/', scopes: [:write_bikes], serializer: BikeV2Serializer, root: 'bike' do
          declared_p = { "declared_params" => declared(params, include_missing: false) }
          b_param = BParam.create(creator_id: current_user.id, params: declared_p['declared_params'], api_v2: true)
          bike = BikeCreator.new(b_param).create_bike
          if b_param.errors.blank? && b_param.bike_errors.blank? && bike.present? && bike.errors.blank?
            bike
          else
            e = bike.present? ? bike.errors : b_param.errors
            error!(e.full_messages, 401)
          end
        end


        desc "Update a bike you own!", {
          notes: <<-NOTE
            **Requires** `read_user` **in the access token** you use to send the notification.
            
            Update a bike owned by the access token you're using.

          NOTE
        }
        params  do 
          requires :id, type: Integer, desc: "Bike ID"
          use :bike_attrs
        end
        put ':id', scopes: [:write_bikes], serializer: BikeV2Serializer, root: 'bike' do
          declared_p = { "declared_params" => declared(params, include_missing: false) }
          find_bike
          authorize_bike_for_user
          hash = BParam.v2_params(declared_p['declared_params'])
          begin
            BikeUpdator.new(user: current_user, b_params: hash).update_available_attributes
          rescue => e
            error!("Unable to update bike: #{e}", 401)
          end
          @bike.reload
        end


        desc "Send a stolen notification", {
          notes: <<-NOTE 
            **Requires** `read_user` **in the access token** you use to send the notification.

            <hr>

            Send a stolen bike notification.

            Your application has to be approved to be able to do this. Email support@bikeindex.org to get access.

            Before your application is approved you can send notifications to yourself (to a bike that you own that's stolen).

          NOTE
        }
        params do 
          requires :id, type: Integer, desc: "Bike ID. **MUST BE A STOLEN BIKE**"
          requires :message, type: String, desc: "The message you are sending to the owner"
        end
        post ':id/send_stolen_notification', scopes: [:read_user], serializer: StolenNotificationSerializer  do 
          find_bike
          error!("Bike is not stolen", 400) unless @bike.present? && @bike.stolen
          # Unless application is authorized....
          authorize_bike_for_user(" (this application is not approved to send notifications)") 
          StolenNotification.create(bike_id: params[:id],
            message: params[:message],
            sender: current_user
          )
        end

      end

    end
  end
end