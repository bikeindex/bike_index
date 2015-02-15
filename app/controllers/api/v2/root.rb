module API
  module V2
    class Root < Dispatch
      format :json
      version 'v2'
      default_error_formatter :json
      content_type :json, 'application/json'
      use ::WineBouncer::OAuth2

      rescue_from :all do |e|
        eclass = e.class.to_s
        message = "OAuth error: #{e.to_s}" if eclass.match('WineBouncer::Errors')
        status = case 
        when eclass.match('OAuthUnauthorizedError')
          401
        when eclass.match('OAuthForbiddenError')
          403
        when eclass.match('RecordNotFound'), e.message.match(/unable to find/i).present?
          404
        else
          (e.respond_to? :status) && e.status || 500
        end
        opts = { error: "#{message || e.message}" }
        opts[:trace] = e.backtrace[0,10] unless Rails.env.production?
        Rack::Response.new(opts.to_json, status, {
          'Content-Type' => "application/json",
          'Access-Control-Allow-Origin' => '*',
          'Access-Control-Request-Method' => '*',
        }).finish
      end
      mount API::V2::BikesSearch
      mount API::V2::Bikes
      mount API::V2::Me
      mount API::V2::Users
      mount API::V2::Manufacturers
      mount API::V2::Selections
      add_swagger_documentation base_path: "/api",
        api_version: 'v2',
        hide_format: true, # don't show .json
        hide_documentation_path: true,
        mount_path: "/swagger_doc",
        markdown: GrapeSwagger::Markdown::KramdownAdapter,
        cascade: false,
        info: {
            title: "BikeIndex API v2",
            description: "This is the API for the Bike Index. It's authenticated with OAuth2 and is generally pretty awesome",
            contact: "support@bikeindex.org",
            license_url: "https://github.com/bikeindex/bike_index/blob/master/LICENSE",
            terms_of_service_url: "https://bikeindex.org/terms"
          }
      route :any, '*path' do
        raise StandardError, "Unable to find endpoint"
      end
    end
  end
end