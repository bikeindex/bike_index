module API
  module V2
    class Bikes < API::V2::Root
      include API::V2::Defaults

      helpers do
        def set_proximity
          return nil unless params[:proximity] == 'ip'
          params[:proximity] = request.env["HTTP_X_FORWARDED_FOR"].split(',')[0]
        end

        def find_bike
          Bike.unscoped.find(params[:id])
        end
      end

      resource :bikes do
        desc "All bike search", {
          notes: <<-NOTE

          NOTE
        }
        paginate
        params do
        end
        get '/', each_serializer: BikeV2Serializer, root: 'bikes' do 
          { "declared_params" => declared(params, include_missing: false) }
          set_proximity
          paginate Bike.scoped
        end

        desc "Stolen bike search", {
          notes: <<-NOTE

          NOTE
        }
        paginate
        params do
        end
        get '/', each_serializer: BikeV2Serializer, root: 'bikes' do 
          { "declared_params" => declared(params, include_missing: false) }
          set_proximity
          paginate Bike.scoped
        end

        desc "Bike matching ID" 
        params do
          requires :id, type: Integer, desc: 'Bike id'
        end
        get ':id', serializer: BikeV2ShowSerializer do 
          bike = find_bike
        end
      end

    end
  end
end