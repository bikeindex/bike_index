module API
  module V3
    class Bikes < API::Base
      include API::V2::Defaults

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

          optional :rear_gear_type_slug, type: String, desc: 'rear gears (has to be one of the `selections`)'
          optional :front_gear_type_slug, type: String, desc: 'front gears (has to be one of the `selections`)'
          optional :handlebar_type_slug, type: String, desc: 'handlebar type (has to be one of the `selections`)'
          optional :no_notify, type: Boolean, desc: "On create or ownership change, don't notify the new owner."
          optional :is_for_sale, type: Boolean
          
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
          optional :component_type, type: String, desc: 'Type of component', values: CTYPE_NAMES
          optional :model, type: String, desc: "Component model"
          optional :year, type: Integer, desc: "Component year"
          optional :description, type: String, desc: "Component description"
          optional :serial, type: String, desc: "Component serial"
          optional :front_or_rear, type: String, desc: "Component front_or_rear"
        end

        def creation_user_id
          if current_user.id == ENV['V2_ACCESSOR_ID'].to_i
            org = params[:organization_slug].present? && Organization.friendly_find(params[:organization_slug])
            if org && current_token.application.owner && current_token.application.owner.is_admin_of?(org)
              return org.auto_user_id
            end
            error!("Permanent tokens can only be used to create bikes for organizations your are an admin of", 403)
          end  
          current_user.id
        end

        def creation_state_params
          {
            is_bulk: params[:is_bulk],
            is_pos: params[:is_pos],
            is_new: params[:is_new],
            no_duplicate: params[:no_duplicate]
          }
        end

        def find_bike
          @bike = Bike.unscoped.find(params[:id])
        end

        def authorize_bike_for_user(addendum='')
          return true if @bike.authorize_bike_for_user!(current_user)
          error!("You do not own that #{@bike.type}#{addendum}", 403)
        end

        def ensure_required_stolen_attrs(hash)
          return true unless hash['bike']['stolen']
          %w(phone city).each do |k|
            error!("Could not create stolen record: missing #{k}", 401) unless hash['stolen_record'][k].present?
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
          declared_p = { "declared_params" => declared(params, include_missing: false).merge(creation_state_params) }
          b_param = BParam.create(creator_id: creation_user_id, params: {'bike': declared_p['declared_params']}, origin: 'api_v3')
          ensure_required_stolen_attrs(b_param.params)
          # Prevents unnecessary DB hits
          if b_param.errors.present? or b_param.bike_errors.present?
            e = b_param.errors
            return error!(e.full_messages.to_sentence, 401)
          end

          existing_bike = Bike.find_by(serial_normalized: SerialNormalizer.new({serial: b_param[:serial]}).normalized)

          # Assume only one bike for now, but may need to check len of existing bike later depending on what Seth says
          if existing_bike.present?
            # Does this check secondary emails?
            authorize_bike_for_user
            begin
              BikeUpdator.new(user: current_user, bike: existing_bike, b_params: b_param).update_available_attributes
            rescue => e
              error!("Unable to update bike: #{e}", 401)
            end
            existing_bike.reload
          end


          bike = BikeCreator.new(b_param).create_bike
          if b_param.errors.blank? && b_param.bike_errors.blank? && bike.present? && bike.errors.blank?
            bike
          else
            e = bike.present? ? bike.errors : b_param.errors
            error!(e.full_messages.to_sentence, 401)
          end
        end
      end
    end
  end
end