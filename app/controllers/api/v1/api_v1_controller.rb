module Api
  module V1
    class ApiV1Controller < ApplicationController
      respond_to :json

      def not_found
        message = { :'404' => "Couldn't find that shit" }
        respond_with message, status: 404
      end
      
      def cors_set_access_control_headers
        headers['Access-Control-Allow-Origin'] = '*'
        headers['Access-Control-Allow-Methods'] = 'POST, PUT, GET, OPTIONS'
        headers['Access-Control-Request-Method'] = '*'
        headers['Access-Control-Allow-Headers'] = 'Origin, X-Requested-With, Content-Type, Accept, Authorization'
        headers['Access-Control-Max-Age'] = "1728000"
      end
      # If this is a preflight OPTIONS request, then short-circuit the
      # request, return only the necessary headers and return an empty
      # text/plain.
      def cors_preflight_check
        if request.method == :options
          headers['Access-Control-Allow-Origin'] = '*'
          headers['Access-Control-Allow-Methods'] = 'POST, GET, OPTIONS'
          headers['Access-Control-Allow-Headers'] = '*'
          headers['Access-Control-Max-Age'] = '1728000'
          render text: '', content_type: 'text/plain'
        end
      end
    end
  end
end