module API
  module V2
    class BikesSearch < API::V2::Root
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
      resource :bikes_search, desc: 'Searching for bikes' do
       
        desc "All bike search", {
          notes: <<-NOTE
            If you want to find any matching bike, use this endpoint.
            You can not use location information here, since this includes non_stolen bikes (which don't have location information)
          NOTE
        }
        paginate
        params do
          use :search_bikes
        end
        get '/', root: 'bikes', each_serializer: BikeV2Serializer do 
          { 'declared_params' => declared(params, include_missing: false) }
          paginate find_bikes
        end

        desc "Stolen bike search", {
          notes: <<-NOTE
            If you want to search for bikes stolen near a specific location, you need to use this endpoint.
            Keep in mind that it only returns stolen bikes - so if you do a serial search, and nothing turns up that doesn't mean that the bike isn't registered.
            **Notes on location searching**: 
            - `proximity` accepts an ip address (IPv6 is supported), an address, zipcode, city, or latitude,longitude. e.g. `70.210.133.87`, `210 NW 11th Ave, Portland, OR`, `60647`, `Chicago, IL`, or `45.521728,-122.67326`
            - `proximity_square` sets the length of the sides of the square to find matches inside of. The square is centered on the location specified by `proximity`. It defaults to 100.
          NOTE
        }
        paginate
        params do
          use :search_bikes
          use :stolen_search
        end
        get '/stolen', root: 'bikes', each_serializer: BikeV2Serializer do 
          params[:stolen] = true
          { 'declared_params' => declared(params, include_missing: false) }
          set_proximity
          paginate find_bikes
        end

        desc "Non-stolen bike search"
        paginate
        params do
          use :search_bikes
        end
        get '/non_stolen', root: 'bikes', each_serializer: BikeV2Serializer do 
          params[:non_stolen] = true
          { 'declared_params' => declared(params, include_missing: false) }
          paginate find_bikes
        end


        desc 'Count of bikes matching search', {
          notes: <<-NOTE
            Include all the options you would pass in in your search. This will respond with a hash of the number of bikes matching your search for each type:

            ```javascript
            {
              "proximity": 19,
              "stolen": 100, 
              "non_stolen": 111
            }
            ```
            `proximity` is the count of matching stolen bikes within the proximity of your search. If no location was included, the location is determined via IP geolocation.
            If you include a serial query, we return `close_serials`
            
            *the `stolen` paramater is ignored, but shown here for consistency*
          NOTE
        }
        params do
          use :search_bikes
          use :stolen_search
        end
        get '/count', root: 'bikes', each_serializer: BikeV2Serializer do
          { 'declared_params' => declared(params, include_missing: false) }
          params[:proximity] = params[:proximity] || "ip"
          set_proximity
          BikeSearcher.new(params).find_bike_counts
        end


        desc 'Close serials', {
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
        get '/close_serials', root: 'bikes', each_serializer: BikeV2Serializer do
          bikes = BikeSearcher.new(params).close_serials
          paginate bikes
        end

        desc 'All stolen bikes', {
          notes: <<-NOTE
            Returns all the stolen bikes. Not paginated, the response is over > 10mb 

            This is a cached response, updated a few times a day. The most recent update time is in the `Last-Modified` header.

            Note: if you load this here, in the documentation, it will take a LONG time because this page parses the response and pretty prints it.
            NOTE
        }
        get '/all_stolen' do
          all_stolen = TsvMaintainer.cached_all_stolen
          header 'Last-Modified', Time.at(all_stolen['updated_at'].to_i).httpdate
          Rails.env.production? ? redirect(all_stolen['path']) : JSON.parse(File.read(all_stolen['path']))
        end
      end
    end
  end
end
