module Api
  module V1
    class ApiV1Controller < ApplicationController
      respond_to :json      
      def default_serializer_options
        {root: false}
      end
    end
  end
end