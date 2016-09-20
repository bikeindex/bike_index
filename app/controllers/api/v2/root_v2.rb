module API
  module V2
    class RootV2 < API::Base
      format :json
      version %w(v3 v2)
      default_error_formatter :json
      content_type :json, 'application/json'
      use ::WineBouncer::OAuth2

      rescue_from :all do |e|
        API::Base.respond_to_error(e)
      end
      mount API::V2::BikesSearch
      mount API::V2::Bikes
      mount API::V2::Me
      mount API::V2::Users
      mount API::V2::Manufacturers
      mount API::V2::Selections
      add_swagger_documentation base_path: '/api',
                                api_version: 'v2',
                                hide_format: true, # don't show .json
                                hide_documentation_path: true,
                                mount_path: '/swagger_doc',
                                markdown: GrapeSwagger::Markdown::KramdownAdapter,
                                cascade: false,
                                info: {
                                  title: 'BikeIndex API v2',
                                  description: "This is the API for the Bike Index. It's authenticated with OAuth2 and is generally pretty awesome",
                                  contact: 'support@bikeindex.org',
                                  license_url: 'https://github.com/bikeindex/bike_index/blob/master/LICENSE',
                                  terms_of_service_url: 'https://bikeindex.org/terms'
                                }
      route :any, '*path' do
        raise StandardError, 'Unable to find endpoint'
      end
    end
  end
end
