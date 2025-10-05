module API
  module V3
    class SwaggerDoc < API::Base
      include API::V2::Defaults

      resource :swagger_doc do
        get "/" do
          {
            apiVersion: "v3",
            swaggerVersion: "1.2",
            produces: ["application/json"],
            apis: [
              {path: "/organizations", description: "Operations about organizations"},
              {path: "/search", description: "Searching for bikes"},
              {path: "/bikes", description: "Operations about bikes"},
              {path: "/me", description: "Operations about the current user"},
              {path: "/manufacturers", description: "Accepted manufacturers"},
              {path: "/selections", description: "Selections (static options)"}
            ],
            info: {
              contact: "support@bikeindex.org",
              description: "\u003cp\u003eThis is the API for Bike Index. It’s authenticated with OAuth2 and is generally pretty awesome\u003c/p\u003e\n",
              licenseUrl: "https://github.com/bikeindex/bike_index/blob/main/LICENSE",
              termsOfServiceUrl: "https://bikeindex.org/terms",
              title: "BikeIndex API v3"
            },
            authorizations: {oauth2: {scope: "read_bikes"}}
          }
        end

        get "/organizations" do
          sendfile "app/views/api/v3/swagger_doc/organizations.json"
        end

        get "/search" do
          sendfile "app/views/api/v3/swagger_doc/search.json"
        end

        get "/bikes" do
          sendfile "app/views/api/v3/swagger_doc/bikes.json"
        end

        get "/me" do
          sendfile "app/views/api/v3/swagger_doc/me.json"
        end

        get "/manufacturers" do
          sendfile "app/views/api/v3/swagger_doc/manufacturers.json"
        end

        get "/selections" do
          sendfile "app/views/api/v3/swagger_doc/selections.json"
        end
      end
    end
  end
end
