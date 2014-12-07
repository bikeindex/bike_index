module API
  module V2
    class Root < Dispatch
      format :json
      mount API::V2::Users
      mount API::V2::Manufacturers
      content_type :json, 'application/json'
      add_swagger_documentation base_path: "/api",
        api_version: 'v2',
        hide_format: true, # don't show .json
        hide_documentation_path: true,
        mount_path: "/v2/swagger_doc",
        markdown: GrapeSwagger::Markdown::KramdownAdapter,
        info: {
            title: "BikeIndex API v2",
            description: "This is the API for the Bike Index. It's authenticated with OAuth2 and is generally pretty awesome",
            contact: "support@bikeindex.org",
            license_url: "https://github.com/bikeindex/bike_index/blob/master/LICENSE",
            terms_of_service_url: "https://bikeindex.org/terms"
          }
    end
  end
end