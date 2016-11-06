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
          optional :stolenness, type: String, values: %w(non stolen proximity all) + [''], default: 'stolen'
          optional :query_items, type: Array, desc: 'Our Fancy select query items, DO NOT USE, may change without notice', documentation: { hidden: true }
        end
        params :search do
          optional :serial, type: String, desc: 'Serial, homoglyph matched'
          use :non_serial_search_params
        end

        def interpreted_params
          Bike.searchable_interpreted_params(params, ip: forwarded_ip_address)
        end

        def serialized_bikes_results(paginated_bikes)
          ActiveModel::ArraySerializer.new(paginated_bikes,
                                           each_serializer: BikeV2Serializer, root: 'bikes')
        end

        def forwarded_ip_address
          request.env['HTTP_X_FORWARDED_FOR'].split(',')[0] if request.env['HTTP_X_FORWARDED_FOR']
        end
      end
      resource :search, desc: 'Searching for bikes' do
        desc 'Search for bikes', {
          notes: <<-NOTE
            `stolenness` is the sort of bikes to match. "**all**": every bike, "**non**": only not-stolen, "**stolen**": all stolen, "**proximity**": only stolen within `distance` of included `location`.

            `location` is ignored unless `stolenness` is "**proximity**"

            `location` can be an address, zipcode, city, or latitude,longitude. e.g. "**210 NW 11th Ave, Portland, OR**", "**60647**", "**Chicago, IL**", or "**45.521728,-122.67326**"
            
            If `location` is "**IP**" (the default), the location is determined via geolocation of your IP address.
          NOTE
        }
        paginate
        params do
          use :search
          optional :per_page, type: Integer, default: 25, desc: 'Bikes per page (max 100)'
        end
        get '/' do
          serialized_bikes_results(paginate Bike.search(interpreted_params))
        end

        desc 'Count of bikes matching search', {
          notes: <<-NOTE
            Include all the options passed in your search. This endpoint accepts the same parameters as the root `/search` endpoint.

            Responds with a hash of the total number of bikes matching your search for each type.

            `proximity` is the count of matching stolen bikes within the proximity of your search.

            ```javascript
            {
              "proximity": 19,
              "stolen": 100,
              "non": 111
            }
            ```

            *The `stolenness` paramater is ignored but allowed here for consistency*
          NOTE
        }
        params do
          use :search
        end
        get '/count' do
          count_interpreted_params = Bike.searchable_interpreted_params(params.merge(stolenness: 'proximity'), ip: forwarded_ip_address)
          {
            proximity: Bike.search(count_interpreted_params).count,
            stolen: Bike.search(count_interpreted_params.merge(stolenness: 'stolen')).count,
            non: Bike.search(count_interpreted_params.merge(stolenness: 'non')).count
          }
        end

        desc 'Search close serials', {
          notes: <<-NOTE
            This endpoint accepts the same parameters as the root `/search` endpoint.

            It returns matches that are off of the submitted `serial` by less than 3 characters (postgres levenshtein, if you're curious).
          NOTE
        }
        paginate
        params do
          requires :serial, type: String, desc: 'Serial, homoglyph matched'
          use :non_serial_search_params
          optional :per_page, type: Integer, default: 25, desc: 'Bikes per page (max 100)'
        end
        get '/close_serials' do
          serialized_bikes_results(paginate Bike.search_close_serials(interpreted_params))
        end
      end
    end
  end
end
