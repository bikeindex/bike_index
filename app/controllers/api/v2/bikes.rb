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
          optional :primary_frame_color, type: String, values: COLOR_NAMES, desc: "Main color of frame (case sensitive match)"
          optional :secondary_frame_color, type: String, values: COLOR_NAMES, desc: "Secondary color (case sensitive match)"
          optional :tertiary_frame_color, type: String, values: COLOR_NAMES, desc: "Third color (case sensitive match)"
          
          optional :stolen_record, type: Hash do
            optional :phone, type: String, desc: "Owner's phone number, **required to create stolen**"
            optional :city, type: String, desc: "City where stolen <br> **required to create stolen**"
            optional :country, type: String, values: COUNTRY_ISOS, desc: "Country the bike was stolen"
            optional :zipcode, type: String, desc: "Where the bike was stolen from"
            optional :state, type: String, desc: "State postal abbreviation if in US - e.g. OR, IL, NY"
            optional :address, type: String, desc: "Public. Use an intersection if you'd prefer the specific address not be revealed"
            optional :date_stolen, type: Integer, desc: "When was the bike stolen (defaults to current time)"

            optional :police_report_number, type: String, desc: 'Police report number'
            optional :police_report_department, type: String, desc: 'Police department reported to (include if report number present)'

          #   # link to LOCKING options!
          #   # optional :locking_description_slug, type: String, desc: 'Locking description. description.'
          #   # optional :lock_defeat_description_slug, type: String, desc: 'Lock defeat description. One of the values from lock defeat desc'
          #   # optional :theft_description, type: String, desc: 'stuff'

          #   # optional :phone_for_everyone, type: Boolean, default: false, desc: 'Show phone number to non logged in users'
          #   # optional :phone_for_users, type: Boolean, default: true, desc: 'Show phone to logged in users'
          end
        end

        params :components_attrs do 
          optional :manufacturer, type: String, desc: "Manufacturer name or ID"
          # [Manufacturer name or ID](api_v2#!/manufacturers/GET_version_manufacturers_format)
          optional :component_type, type: String, desc: 'Type of component', values: CTYPE_NAMES, desc: 'Type - case sensitive match'
          optional :model, type: String, desc: "Component model"
          optional :year, type: Integer, desc: "Component year"
          optional :description, type: String, desc: "Component description"
          optional :serial, type: String, desc: "Component serial"
          optional :front_or_rear, type: String, desc: "Component front_or_rear"
        end

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

        def ensure_required_stolen_attrs(hash)
          return true unless hash[:bike][:stolen]
          [:phone, :city].each do |k|
            error!("Could not create stolen record: missing #{k.to_s}", 401) unless hash[:stolen_record][k].present?
          end
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


        desc "Add a bike to the Index!<span class='accstr'>*</span>", {
          authorizations: { oauth2: [{ scope: :write_bikes }] },
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
          optional :cycle_type_name, type: String, values: CYCLE_TYPE_NAMES, default: 'bike', desc: "Type of cycle (case sensitive match)"
          use :bike_attrs
          optional :components, type: Array do
            use :components_attrs
          end
        end
        post '/', serializer: BikeV2ShowSerializer, root: 'bike' do
          declared_p = { "declared_params" => declared(params, include_missing: false) }
          b_param = BParam.create(creator_id: current_user.id, params: declared_p['declared_params'], api_v2: true)
          ensure_required_stolen_attrs(b_param.params)
          bike = BikeCreator.new(b_param).create_bike
          if b_param.errors.blank? && b_param.bike_errors.blank? && bike.present? && bike.errors.blank?
            bike
          else
            e = bike.present? ? bike.errors : b_param.errors
            error!(e.full_messages.to_sentence, 401)
          end
        end


        desc "Update a bike owned by the access token<span class='accstr'>*</span>", {
          authorizations: { oauth2: [{ scope: :write_bikes }] },
          notes: <<-NOTE
            **Requires** `read_user` **in the access token** you use to send the notification.
            
            Update a bike owned by the access token you're using.

          NOTE
        }
        params  do 
          requires :id, type: Integer, desc: "Bike ID"
          use :bike_attrs
          optional :owner_email, type: String, desc: "Send the bike to a new owner!"
          optional :components, type: Array do
            optional :id, type: Integer, desc: "Component ID - if you don't supply this you will create a new component instead of update an existing one"
            use :components_attrs
            optional :destroy, type: Boolean, desc: "Delete this component (requires an ID)"
          end
        end
        put ':id', serializer: BikeV2ShowSerializer, root: 'bike' do
          declared_p = { "declared_params" => declared(params, include_missing: false) }
          find_bike
          authorize_bike_for_user
          hash = BParam.v2_params(declared_p['declared_params'])
          ensure_required_stolen_attrs(hash) if hash[:stolen_record].present? && @bike.stolen != true
          begin
            BikeUpdator.new(user: current_user, b_params: hash).update_available_attributes
          rescue => e
            error!("Unable to update bike: #{e}", 401)
          end
          @bike.reload
        end

        desc "Add an image to a bike", {
          authorizations: { oauth2: [{ scope: :write_bikes }] },
          notes: <<-NOTE

            To post a file to the API with curl:

            `curl -X POST -i -F file=@{test_file.jpg} "#{ENV['BASE_URL']}/api/v2/bikes/{bike_id}/image?access_token={access_token}"`

            Replace `{text_file.jpg}` with the relative path of the file you're posting.

            **RIGHT NOW THIS DEMO DOESN'T WORK.** The `curl` command above does. We're working on the documentation issue, check back soon.

          NOTE
        }
        params  do 
          requires :id, type: Integer, desc: "Bike ID"
          requires :file, :type => Rack::Multipart::UploadedFile, :desc => "Attachment."
        end
        post ':id/image', serializer: PublicImageSerializer, root: 'image' do 
          declared_p = { "declared_params" => declared(params, include_missing: false) }
          find_bike
          authorize_bike_for_user
          public_image = PublicImage.new(imageable: @bike, image: params[:file])
          if public_image.save
            public_image
          else
            error!(public_image.errors.full_messages.to_sentence, 401)
          end
        end


        desc "Send a stolen notification<span class='accstr'>*</span>", {
          authorizations: { oauth2: [{ scope: :read_user }] },
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
        post ':id/send_stolen_notification', serializer: StolenNotificationSerializer  do 
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