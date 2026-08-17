module API
  module V3
    class RootV3 < API::Base
      format :json
      version "v3"
      default_error_formatter :json
      content_type :json, "application/json"

      mount API::V3::Organizations
      mount API::V3::Search
      mount API::V2::Bikes
      mount API::V3::Me
      mount API::V2::Manufacturers
      mount API::V2::Selections
      mount API::V3::SwaggerDoc

      route :any, "*path" do
        raise GrapeErrors::EndpointNotFound, "Unable to find endpoint"
      end
    end
  end
end
