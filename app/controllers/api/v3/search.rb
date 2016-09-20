module API
  module V3
    class Search < API::Base
      helpers do
        params :non_serial_search_params do
          optional :query, type: String, desc: 'Full text search'
          optional :manufacturer, type: String
          optional :colors, type: Array
          optional :location, type: String, desc: 'Location for proximity search', default: 'IP'
          optional :distance, type: String, desc: 'Distance in miles from `location` for proximity search', default: 10
          optional :stolenness, type: String, values: %w(non stolen proximity all), default: 'stolen'
          optional :query_items, type: Array
        end
        params :search do
          optional :serial, type: String, desc: 'Serial, homoglyph matched'
          use :non_serial_search_params
        end

        def forwarded_ip_address
          request.env['HTTP_X_FORWARDED_FOR'].split(',')[0] if request.env['HTTP_X_FORWARDED_FOR']
        end
      end
      resource :search, desc: 'Searching for bikes' do
        desc 'Count of bikes matching search', {
          notes: <<-NOTE
            - `stolenness` is the sort of bikes to match. `all`: everything, `non`: only not-stolen, `stolen`: all stolen, `proximity`: only within `distance` of `location`.
            - `query_items` is the special formatted array used by our fancy select on the frontend. It's included here so you can use the same parameters for HTML and API. You probably don't want to use it.
            - `location` is ignored unless `stolenness` is 'proximity'
            - If `location` is 'IP' (the default), the location is determined via geolocation of your IP address.


            Include all the options passed in your search. This will respond with a hash of the number of bikes matching your search for each type:

            ```javascript
            {
              "proximity": 19,
              "stolen": 100, 
              "non": 111
            }
            ```

            `proximity` is the count of matching stolen bikes within the proximity of your search.

            *the `stolen` paramater is ignored, but allowed here for consistency*
          NOTE
        }
        params do
          use :search
        end
        get '/count', root: 'bikes', each_serializer: BikeV2Serializer do
          # { 'declared_params' => declared(params, include_missing: false) }
          interpreted_params = Bike.searchable_interpreted_params(params.merge(stolenness: 'proximity'), ip: forwarded_ip_address)
          {
            proximity: Bike.search(interpreted_params).count,
            stolen: Bike.search(interpreted_params.merge(stolenness: 'stolen')).count,
            non: Bike.search(interpreted_params.merge(stolenness: 'non')).count
          }
        end
      end
    end
  end
end
