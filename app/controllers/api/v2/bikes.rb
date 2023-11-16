module API
  module V2
    class Bikes < API::Base
      include API::V2::Defaults

      CYCLE_TYPE_NAMES = CycleType::NAMES.values.map(&:downcase)
      PROPULSION_TYPES = PropulsionType::SLUGS
      # When running bin/setup, things break if the database isn't setup. Also use default in test
      STATIC_VALS = Rails.env.test? || !!Ctype
      CTYPE_NAMES = (STATIC_VALS ? ["wheel", "headset"] : Ctype.pluck(:name).map(&:downcase)).freeze
      COLOR_NAMES = (STATIC_VALS ? ["black", "orange"] : Color.pluck(:name).map(&:downcase)).freeze
      COUNTRY_ISOS = (STATIC_VALS ? ["US"] : Country.pluck(:iso)).freeze

      helpers do
        params :bike_attrs do
          optional :rear_wheel_bsd, type: Integer, desc: "Rear wheel iso bsd (has to be one of the `selections`)"
          optional :rear_tire_narrow, type: Boolean, desc: "Boolean. Is it a skinny tire?"
          optional :front_wheel_bsd, type: String, desc: "Copies `rear_wheel_bsd` if not set"
          optional :front_tire_narrow, type: Boolean, desc: "Copies `rear_tire_narrow` if not set"
          optional :frame_model, type: String, desc: "What frame model?"
          optional :year, type: Integer, desc: "What year was the frame made?"
          optional :description, type: String, desc: "General description"
          optional :primary_frame_color, type: String, values: COLOR_NAMES, desc: "Main color of frame (case sensitive match)"
          optional :secondary_frame_color, type: String, values: COLOR_NAMES, desc: "Secondary color (case sensitive match)"
          optional :tertiary_frame_color, type: String, values: COLOR_NAMES, desc: "Third color (case sensitive match)"
          optional :rear_gear_type_slug, type: String, desc: "rear gears (has to be one of the `selections`)"
          optional :front_gear_type_slug, type: String, desc: "front gears (has to be one of the `selections`)"
          optional :extra_registration_number, type: String, desc: "Additional serial or registration number (not the original serial)"
          optional :handlebar_type_slug, type: String, desc: "handlebar type (has to be one of the `selections`)"
          optional :no_notify, type: Boolean, desc: "On create or ownership change, don't notify the new owner."
          optional :is_for_sale, type: Boolean
          optional :frame_material, type: String, values: Bike.frame_materials.keys, desc: "Frame material type"
          optional :external_image_urls, type: Array, desc: "Image urls to include with registration, if images are already on the internet"
          optional :bike_sticker, type: String, desc: "Bike Sticker code"
          optional :propulsion_type_slug, type: String, values: PROPULSION_TYPES, default: "foot-pedal", desc: "Propulsion Type slug"

          optional :stolen_record, type: Hash do
            optional :phone, type: String, desc: "Owner's phone number, **required to create stolen**"
            optional :city, type: String, desc: "City where stolen <br> **required to create stolen**"
            optional :country, type: String, values: COUNTRY_ISOS, desc: "Country the bike was stolen"
            optional :zipcode, type: String, desc: "Where the bike was stolen from"
            optional :state, type: String, desc: "State postal abbreviation if in US - e.g. OR, IL, NY"
            optional :address, type: String, desc: "Public. Use an intersection if you'd prefer the specific address not be revealed"
            optional :date_stolen, type: Integer, desc: "When was the bike stolen (defaults to current time)"

            optional :police_report_number, type: String, desc: "Police report number"
            optional :police_report_department, type: String, desc: "Police department reported to (include if report number present)"
            # show_address NO LONGER ACTUALLY DOES ANYTHING. Keeping so that the API doesn't change
            optional :show_address, type: Boolean, desc: "Display the exact address the theft happened at"

            optional :theft_description, type: String, desc: "stuff"

            # link to LOCKING options!
            # optional :locking_description_slug, type: String, desc: "Locking description. description."
            # optional :lock_defeat_description_slug, type: String, desc: "Lock defeat description. One of the values from lock defeat desc"
            # optional :phone_for_everyone, type: Boolean, default: false, desc: 'Show phone number to non logged in users'
            # optional :phone_for_users, type: Boolean, default: true, desc: 'Show phone to logged in users'
          end
        end

        params :components_attrs do
          optional :manufacturer, type: String, desc: "Manufacturer name or ID"
          # [Manufacturer name or ID](api_v2#!/manufacturers/GET_version_manufacturers_format)
          optional :component_type, type: String, desc: "Type of component", values: CTYPE_NAMES
          optional :model, type: String, desc: "Component model"
          optional :year, type: Integer, desc: "Component year"
          optional :description, type: String, desc: "Component description"
          optional :serial, type: String, desc: "Component serial"
          optional :front_or_rear, type: String, desc: "Component front_or_rear"
        end

        def creation_user_id
          if current_user&.id == ENV["V2_ACCESSOR_ID"].to_i || doorkeeper_authorized_no_user
            # current_organization requires token user to be authorized - V2_ACCESSOR is not
            organization = Organization.friendly_find(params[:organization_slug])
            if organization.present? && current_token&.application&.owner&.admin_of?(organization)
              @current_organization = organization
              return current_organization.auto_user_id
            end

            if doorkeeper_authorized_no_user
              error!("Access tokens with no user can only be used to create bikes for organizations you're an admin of", 403)
            else
              error!("Permanent tokens can only be used to create bikes for organizations you're an admin of", 403)
            end
          end
          current_user.id
        end

        def creation_state_params
          {
            is_bulk: params[:is_bulk],
            is_pos: params[:is_pos],
            is_new: params[:is_new]
          }.as_json
        end

        def find_bike
          @bike = Bike.unscoped.find(params[:id])
        end

        def owner_duplicate_bike
          manufacturer_id = Manufacturer.friendly_find_id(params[:manufacturer])
          OwnerDuplicateBikeFinder.matching(serial: params[:serial],
            owner_email: params[:owner_email_is_phone_number] ? nil : params[:owner_email],
            phone: params[:owner_email_is_phone_number] ? params[:owner_email] : nil,
            manufacturer_id: manufacturer_id).first
        end

        def created_bike_serialized(bike, include_claim_token)
          serialized = BikeV2ShowSerializer.new(bike, root: false)
          claim_url = serialized.url + (include_claim_token ? "?t=#{bike.current_ownership.token}" : "")
          {bike: serialized, claim_url: claim_url}
        end

        def authorize_bike_for_user(addendum = "")
          return true if @bike.authorize_and_claim_for_user(current_user)
          error!("You do not own that #{@bike.type}#{addendum}", 403)
        end

        def origin_api_version
          request.path_info.to_s&.match?("v3") ? "api_v3" : "api_v2"
        end
      end

      resource :bikes do
        desc "View bike with a given ID"
        params do
          requires :id, type: Integer, desc: "Bike id"
        end
        get ":id" do
          BikeV2ShowSerializer.new(find_bike, root: "bike").as_json
        end

        desc "Check if a bike is already registered <span class='accstr'>*</span>", {
          authorizations: {oauth2: {scope: :write_bikes, allow_client_credentials: true}},
          notes: <<-NOTE
            **Access token user** _must_ be a member of the organization from the `organization_slug`.

            It matches on `serial`, `owner_email` and `manufacturer`. No matches are returned if the serial is 'made_without_serial' or 'unknown'.

            This is the matching that happens when adding bikes, to prevent duplicate registrations. By default, adding a bike will update the existing bike if there is a match _which can be edited_ - and will create a new bike if the existing match can't be edited (If you include `no_duplicate` when adding a bike, it won't add a duplicate bike in that situation).

            The only difference between this and the behavior of add a bike, is that `manufacturer` is optional here.

            Returns JSON with keys:

            - `registered`: If a match was found
            - `claimed`: If a match was found and the user has claimed the bike
            - `can_edit`: If a match was found and it can be edited by the current token (e.g. was registered by the organization)

            <br>

            All values are either `true` or `false`
          NOTE
        }
        params do
          requires :serial, type: String, desc: "The serial number for the bike (use 'made_without_serial' if the bike doesn't have a serial, 'unknown' if the serial is not known)"
          requires :owner_email, type: String, desc: "Owner email"
          requires :organization_slug, type: String, desc: "Organization (ID or slug) to perform the check from. **Only works** if user is a member of the organization"
          optional :manufacturer, type: String, desc: "Manufacturer name or ID"
          optional :owner_email_is_phone_number, type: Boolean, desc: "If using a phone number for registration, rather than email"
        end
        post "check_if_registered" do
          if current_organization.present?
            matching_bike = owner_duplicate_bike
            {
              registered: matching_bike.present?,
              claimed: matching_bike.present? && matching_bike.claimed?,
              can_edit: matching_bike.present? && matching_bike.authorized?(current_user)
            }
          else
            error!("You are not authorized for that organization", 401)
          end
        end

        desc "Add a bike to the Index! <span class='accstr'>*</span>", {
          authorizations: {oauth2: {scope: :write_bikes, allow_client_credentials: true}},
          notes: <<-NOTE
            **Requires** `write_bikes` **in the access token** you use to create the bike.

            <hr>

            **Creating test bikes**: To create test bikes, set `test` to true. These bikes:

            - Do not show turn up in searches
            - Do not send an email to the owner on creation
            - Are automatically deleted after a few days
            - Can be viewed in the API /v3/bikes/{id} (same as non-test bikes)
            - Can be viewed on the HTML site /bikes/{id} (same as non-test bikes)

            *`test` is automatically marked true on this documentation page. Set it to false it if you want to create actual bikes*

            **Ownership**: Bikes you create will be created by the user token you authenticate with, but they will be sent to the email address you specify.

          NOTE
        }
        params do
          requires :serial, type: String, desc: "The serial number for the bike (use 'made_without_serial' if the bike doesn't have a serial, 'unknown' if the serial is not known)"
          requires :manufacturer, type: String, desc: "Manufacturer name or ID"
          # [Manufacturer name or ID](api_v2#!/manufacturers/GET_version_manufacturers_format)
          requires :owner_email, type: String, desc: "Owner email"
          optional :owner_email_is_phone_number, type: Boolean, desc: "If using a phone number for registration, rather than email"
          requires :color, type: String, desc: "Main color or paint - does not have to be one of the accepted colors"
          optional :test, type: Boolean, desc: "Is this a test bike?"
          optional :organization_slug, type: String, desc: "Organization (ID or slug) bike should be created by. **Only works** if user is a member of the organization"
          optional :cycle_type_name, type: String, values: CYCLE_TYPE_NAMES, default: "bike", desc: "Type of cycle (case sensitive match)"
          optional :no_duplicate, type: Boolean, default: false, desc: "If true, it won't register a duplicate bike - when it can't edit an existing matching bike (see `/check_if_registered`)"
          use :bike_attrs
          optional :components, type: Array do
            use :components_attrs
          end
        end
        post "/" do
          declared_p = declared(params, include_missing: false)
          add_duplicate = declared_p.delete("add_duplicate")
          # TODO: BikeCreator also includes bike finding, and this duplicates it - it would be nice to DRY this up
          # It's required so that the bike can be updated if there is a match
          found_bike = owner_duplicate_bike unless add_duplicate
          # if a matching bike exists and can be updated by the submitter, update instead of creating a new one
          if found_bike.present? && found_bike.authorized?(current_user)
            b_param = BParam.new(creator_id: creation_user_id, params: declared_p.as_json, origin: origin_api_version)
            b_param.clean_params
            @bike = found_bike
            authorize_bike_for_user

            if b_param.params.dig("bike", "external_image_urls").present?
              @bike.load_external_images(b_param.params["bike"]["external_image_urls"])
            end
            if b_param.bike_sticker_code.present?
              bike_sticker = BikeSticker.lookup_with_fallback(b_param.bike_sticker_code, organization_id: current_organization&.id)
              # Don't reclaim an already claimed sticker
              if bike_sticker.present? && bike_sticker.bike_id != found_bike.id
                bike_sticker.claim_if_permitted(user: found_bike.creator, bike: found_bike.id, organization: current_organization)
              end
            end
            begin
              # Don't update the email (or is_phone), because maybe they have different user emails
              bike_update_params = b_param.params.merge("bike" => b_param.bike.except(:owner_email, :is_phone, :no_duplicate))
              BikeUpdator
                .new(user: current_user, bike: @bike, b_params: bike_update_params)
                .update_available_attributes
            rescue => e
              error!("Unable to update bike: #{e}", 401)
            end

            status :found
            return created_bike_serialized(@bike.reload, false)
          end
          b_param = BParam.new(creator_id: creation_user_id, origin: origin_api_version,
            params: declared_p.merge(creation_state_params).as_json)
          b_param.save
          bike = BikeCreator.new.create_bike(b_param)

          if b_param.errors.blank? && b_param.bike_errors.blank? && bike.present? && bike.errors.blank?
            created_bike_serialized(bike, true)
          else
            e = bike.present? ? bike.errors : b_param.errors
            error!(e.full_messages.to_sentence, 401)
          end
        end

        desc "Update a bike owned by the access token<span class='accstr'>*</span>", {
          authorizations: {oauth2: {scope: :write_bikes, allow_client_credentials: true}},
          notes: <<-NOTE
            **Requires** `write_bikes` **in the access token** you use to send the notification.

            Update a bike owned by the access token you're using.

          NOTE
        }
        params do
          requires :id, type: Integer, desc: "Bike ID"
          use :bike_attrs
          optional :owner_email, type: String, desc: "Send the bike to a new owner!"
          optional :components, type: Array do
            optional :id, type: Integer, desc: "Component ID - if you don't supply this you will create a new component instead of update an existing one"
            use :components_attrs
            optional :destroy, type: Boolean, desc: "Delete this component (requires an ID)"
          end
        end
        put ":id" do
          declared_p = declared(params, include_missing: false)
          find_bike
          authorize_bike_for_user
          b_param = BParam.new(params: declared_p.as_json, origin: origin_api_version)
          b_param.clean_params
          hash = b_param.params
          @bike.load_external_images(hash["bike"]["external_image_urls"]) if hash.dig("bike", "external_image_urls").present?
          begin
            BikeUpdator.new(user: current_user, bike: @bike, b_params: hash).update_available_attributes
          rescue => e
            error!("Unable to update bike: #{e}", 401)
          end
          BikeV2ShowSerializer.new(@bike.reload, root: "bike").as_json
        end

        desc "Mark a bike recovered that is owned by the access token<span class='accstr'>*</span>", {
          authorizations: {oauth2: {scope: :write_bikes, allow_client_credentials: true}},
          notes: <<-NOTE
            **Requires** `write_bikes` **in the access token** you use to send the notification.

            Update a bike owned by the access token you're using.

          NOTE
        }
        params do
          requires :id, type: Integer, desc: "Bike ID"
          optional :recovered_at, type: Integer, desc: "Timestamp when the bike was recovered (defaults to current time)"
          requires :recovered_description, type: String, desc: "Description of the recovery"
          optional :index_helped_recovery, type: Boolean, desc: "Did Bike Index help recover this bike?"
          optional :can_share_recovery, type: Boolean, desc: "Can Bike Index share information about this recovery?"
        end
        put ":id/recover" do
          find_bike
          authorize_bike_for_user
          error!("Bike is not stolen", 400) unless @bike.present? && @bike.status_stolen?
          declared_p = declared(params, include_missing: false)
          @bike.current_stolen_record.add_recovery_information(declared_p)

          BikeV2ShowSerializer.new(@bike.reload, root: "bike").as_json
        end

        desc "Add an image to a bike <span class='accstr'>*</span>", {
          authorizations: {oauth2: {scope: :write_bikes, allow_client_credentials: true}},
          notes: <<-NOTE

            To post a file to the API with curl:

            `curl -X POST -i -F file=@{test_file.jpg} "#{ENV["BASE_URL"]}/api/v3/bikes/{bike_id}/image?access_token={access_token}"`

            Replace `{text_file.jpg}` with the relative path of the file you're posting.

            **RIGHT NOW THIS DEMO DOESN'T WORK.** The `curl` command above does. We're working on the documentation issue, check back soon.

          NOTE
        }
        params do
          requires :id, type: Integer, desc: "Bike ID"
          requires :file, type: Rack::Multipart::UploadedFile, desc: "Attachment."
        end
        post ":id/image" do
          find_bike
          authorize_bike_for_user
          public_image = PublicImage.new(imageable: @bike, image: params[:file])
          if public_image.save
            PublicImageSerializer.new(public_image, root: "image").as_json
          else
            error!(public_image.errors.full_messages.to_sentence, 401)
          end
        end

        desc "Remove an image from a bike <span class='accstr'>*</span>", {
          authorizations: {oauth2: {scope: :write_bikes, allow_client_credentials: true}},
          notes: <<-NOTE

            Remove an image from the bike, specifying both the bike_id and the image id (which can be found in the public_images resopnse)

            **Requires** `write_bikes` **in the access token** you use.

          NOTE

        }
        params do
          requires :id, type: Integer, desc: "Bike ID"
          requires :image_id, type: Integer, desc: "Image ID"
        end
        delete ":id/images/:image_id" do
          find_bike
          authorize_bike_for_user
          public_image = @bike.public_images.find_by_id(params[:image_id])
          error!("Unable to find that image", 404) unless public_image.present?
          public_image.destroy
          BikeV2ShowSerializer.new(@bike.reload, root: "bike").as_json
        end

        desc "Send a stolen notification <span class='accstr'>*</span>", {
          authorizations: {oauth2: {scope: :read_user}},
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
        post ":id/send_stolen_notification" do
          find_bike
          error!("Bike is not stolen", 400) unless @bike.present? && @bike.status_stolen?
          # Unless application is authorized....
          authorize_bike_for_user(" (this application is not approved to send notifications)")
          stolen_notification = StolenNotification.create(bike_id: params[:id],
            message: params[:message],
            sender: current_user)
          StolenNotificationSerializer.new(stolen_notification).as_json
        end
      end
    end
  end
end
