module API
  module V2
    class RootV2 < API::Base
      version %w[v3 v2]

      mount API::V2::BikesSearch
      mount API::V2::Bikes
      mount API::V2::Me
      mount API::V2::Users
      mount API::V2::Manufacturers
      mount API::V2::Selections
      mount API::V2::SwaggerDoc

      route :any, "*path" do
        raise API::EndpointNotFound, "Unable to find endpoint"
      end
    end
  end
end
