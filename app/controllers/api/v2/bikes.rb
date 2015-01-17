module API
  module V2
    class Bikes < API::V2::Root
      include API::V2::Defaults

      helpers do
        params :search_bikes do 
          optional :colors, type: String, desc: "Comma separated list. Results will match **all** colors"
          # [View colors we accept](#!/selections/GET_version_selections_format)
          optional :manufacturer, type: String, desc: "Manufacturer name or ID"
          # [Manufacturer name or ID](api_v2#!/manufacturers/GET_version_manufacturers_format)
          optional :query, type: String, desc: "Full text search of bikes, their attributes and components"
          optional :serial, type: String, desc: "Serial number"
        end

        params :stolen_search do 
          optional :proximity, type: String, desc: "Center of location for proximity search", documentation: { example: '45.521728,-122.67326'}
          optional :proximity_square, type: Integer, desc: "Size of the proximity search", default: 100
          optional :stolen_before, type: Integer, desc: "Bikes stolen before timestamp"
          optional :stolen_after, type: Integer, desc: "Bikes stolen after timestamp"
        end

        params :bike_attrs do           
          optional :rear_wheel_bsd, type: Integer, desc: "rear_wheel_bsd"
          # optional :rear_tire_narrow, type: Boolean, desc: "boolean. Is it a skinny tire?"

          optional :rear_wheel_bsd, type: String, desc: "Duplicates `rear_wheel_bsd` if not set"
          # optional :rear_tire_narrow, type: Boolean, desc: "Duplicates `rear_tire_narrow` if not set"
          
          optional :frame_model, type: String, desc: "What frame model?"
          optional :year, type: Integer, desc: "What year was the frame made?"
          optional :description, type: String, desc: "General description"
        end

        def find_bike
          Bike.unscoped.find(params[:id])
        end

        def authorize_bike_for_user

        end

        def find_bikes
          BikeSearcher.new(params).find_bikes
        end

        def set_proximity
          params[:proximity_radius] = params[:proximity_square] ||= 100
          return nil unless params[:proximity] == 'ip'
          if Rails.env == 'production'
            params[:proximity] = request.env["HTTP_X_FORWARDED_FOR"].split(',')[0]
          end
        end
      end

      resource :bikes do
        desc "All bike search", {
          notes: <<-NOTE
            If you find any matching bike, use this endpoint.
            You can not use location information here, since this includes non_stolen bikes (which don't have location information)
          NOTE
        }
        paginate
        params do
          use :search_bikes
        end
        get '/', each_serializer: BikeV2Serializer do 
          { "declared_params" => declared(params, include_missing: false) }
          paginate find_bikes
        end


        desc "Non-stolen bike search"
        paginate
        params do
          use :search_bikes
        end
        get '/non_stolen', each_serializer: BikeV2Serializer do 
          params[:non_stolen] = true
          { "declared_params" => declared(params, include_missing: false) }
          paginate find_bikes
        end


        desc "Stolen bike search", {
          notes: <<-NOTE
            If you want to search for bikes stolen near a specific location, you need to use this endpoint.
            Keep in mind that it only returns stolen bikes - so if you do a serial search, and nothing turns up that doesn't mean that the bike isn't registered.
            **Notes on location searching**: 
            - `proximity` accepts an ip address (IPv6 is supported), an address, zipcode, city, or latitude,longitude. e.g. `70.210.133.87`, `210 NW 11th Ave, Portland, OR`, `60647`, `Chicago, IL`, or `45.521728,-122.67326`
            - `proximity_square` sets the length of the sides of the square to find matches inside of. The square is centered on the location specified by `proximity`. It defaults to 500.
          NOTE
        }
        paginate
        params do
          use :search_bikes
          use :stolen_search
        end
        get '/stolen', each_serializer: BikeV2Serializer do 
          params[:stolen] = true
          { "declared_params" => declared(params, include_missing: false) }
          set_proximity
          paginate find_bikes
        end


        desc "Count of bikes matching search", {
          notes: <<-NOTE
            Use all the options you would pass in other places, responds with how many of bikes there are of each type:
            Unless you pass a proximity, we use IP geolocation. If you include a serial query, we return `close_serials`

            ```javascript
            {
              "proximity": X, // Proximity for ip address unless specified
              "stolen": X, 
              "non_stolen": X
            }
            ```

            *the `stolen` paramater is ignored, but shown here for consistency*
          NOTE
        }
        params do
          use :search_bikes
          use :stolen_search
        end
        get '/count', protected: false, each_serializer: BikeV2Serializer do
          { "declared_params" => declared(params, include_missing: false) }
          params[:proximity] = params[:proximity] || "ip"
          set_proximity
          BikeSearcher.new(params).find_bike_counts
        end


        desc "Close serials", {
          notes: <<-NOTE
            We can find bikes with serials close to the serial you search you input.
            Close serials are serials that are off by one or two characters
            Note: [Homoglyph](https://en.wikipedia.org/wiki/Homoglyph) matching happens for all endpoints (e.g. 1GGGGO will find IGGG0), you don't need to use `close_serials` to get it.
          NOTE
        }
        paginate
        params do 
          requires :serial, type: String, desc: "Serial to search for"
        end
        get '/close_serials', each_serializer: BikeV2Serializer do
          bikes = BikeSearcher.new(params).close_serials
          paginate bikes
        end


        desc "View bike with a give ID" 
        params do
          requires :id, type: Integer, desc: 'Bike id'
        end
        get ':id', serializer: BikeV2ShowSerializer do 
          bike = find_bike
        end


      #   desc "Add a bike to the Index!", {
      #     notes: <<-NOTE
      #       **Creating test bikes**: To create test bikes, set `test` to true. These bikes:

      #       - Do not show turn up in searches
      #       - Do not send an email to the owner on creation
      #       - Are automatically deleted after a few days
      #       - You can view them in the API /v2/bikes/{id} (same as normal bikes)
      #       - You can view them on the HTML site (same as normal bikes)

      #       *`test` is automatically marked true on this documentation page. Set it to false it if you want to create actual bikes*

      #       **Ownership**: Bikes you create will be created by the user token you authenticate with, but they will be sent to the email address you specify.
            
      #     NOTE
      #   }
      #   params do 
      #     requires :serial_number, type: String, desc: "The serial number for the bike"
      #     requires :manufacturer, type: String, desc: "Manufacturer name or ID"
      #     # [Manufacturer name or ID](api_v2#!/manufacturers/GET_version_manufacturers_format)

      #     # optional :test, type: Boolean, desc: "Is this a test bike?"
      #     requires :owner_email, type: String, desc: "Owner email"
      #     requires :primary_frame_color, type: String, desc: "Color"
      #     optional :secondary_frame_color, type: String, desc: "Color"
      #     optional :tertiary_frame_color, type: String, desc: "Color"

      #     optional :stolen, type: Hash do 
      #       requires :phone, type: String, desc: "Owner's phone number"
      #       requires :city, type: String, desc: "Where the bike was stolen"
      #       requires :country, type: String, desc: "Where the bike was stolen"
      #       optional :zipcode, type: String, desc: "Where the bike was stolen"
      #       optional :state, type: String, desc: "Where the bike was stolen"
      #       optional :address, type: String, desc: "Where the bike was stolen"
      #       requires :date_stolen, type: Integer, desc: "When was the bike stolen"
      #     end

      #     optional :components, type: Array do
      #       requires :manufacturer, type: String, desc: "Manufacturer name or ID"
      #       # [Manufacturer name or ID](api_v2#!/manufacturers/GET_version_manufacturers_format)
      #       requires :ctype
      #     end

      #     use :bike_attrs 
      #   end
      #   post do 
      #     authorize_bike_for_user
      #     # { "declared_params" => declared(params, include_missing: false) }

      #   end

      end

    end
  end
end