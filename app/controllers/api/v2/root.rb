module API
  module V2
    class Root < Dispatch
      format :json
      mount API::V2::Manufacturers
      mount API::V2::Users
      content_type :json, 'application/json'
      add_swagger_documentation base_path: "/api",
        api_version: 'v2',
        hide_format: true, # don't show .json
        hide_documentation_path: true,
        info: {
            title: "BikeIndex API v1",
            description: "This is an API for accessing information about bicycling related incidents. You can find the source code on <a href='https://github.com/bikeindex/bikewise'>GitHub</a>."
          }
    end
  end
end