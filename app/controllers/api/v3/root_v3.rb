module API
  module V3
    class RootV3 < API::Base
      format :json
      version "v3"
      default_error_formatter :json
      content_type :json, "application/json"
      use ::WineBouncer::OAuth2

      rescue_from :all do |e|
        API::Base.respond_to_error(e)
      end
      mount API::V3::Search
      mount API::V2::Bikes
      mount API::V3::Me
      mount API::V2::Manufacturers
      mount API::V2::Selections
      add_swagger_documentation base_path: "/api",
                                api_version: "v3",
                                hide_format: true, # don't show .json
                                hide_documentation_path: true,
                                mount_path: "/swagger_doc",
                                markdown: GrapeSwagger::Markdown::KramdownAdapter,
                                cascade: false,
                                info: {
                                  title: "BikeIndex API v3",
                                  description: "This is the API for Bike Index. It's authenticated with OAuth2 and is generally pretty awesome",
                                  contact: "support@bikeindex.org",
                                  license_url: "https://github.com/bikeindex/bike_index/blob/master/LICENSE",
                                  terms_of_service_url: "https://bikeindex.org/terms"
                                }
      route :any, "*path" do
        raise StandardError, "Unable to find endpoint"
      end
    end
  end
end
