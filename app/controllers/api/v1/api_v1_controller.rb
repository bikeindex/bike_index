module Api
  module V1
    class ApiV1Controller < ApplicationController
      respond_to :json

      def not_found
        message = { :'error' => "404 - Couldn't find that shit" }
        respond_with message, status: 404
      end
      
    end
  end
end