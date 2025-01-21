module API
  module V2
    class RootV2 < API::Base
      format :json
      version %w[v3 v2]
      default_error_formatter :json
      content_type :json, "application/json"

      rescue_from :all do |e|
        API::Base.respond_to_error(e)
      end
      mount API::V2::BikesSearch
      mount API::V2::Bikes
      mount API::V2::Me
      mount API::V2::Users
      mount API::V2::Manufacturers
      mount API::V2::Selections
      mount API::V2::SwaggerDoc

      route :any, "*path" do
        raise StandardError, "Unable to find endpoint"
      end
    end
  end
end
