module API
  module V2
    class Bikes < API::V2::Root
      include API::V2::Defaults

      helpers do
        def find_bike
          Bike.unscoped.find(params[:id])
        end

      end

      resource :bikes do
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