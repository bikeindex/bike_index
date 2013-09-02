module Api
  module V1
    class HandlebarTypesController < ApiV1Controller
      def index
        respond_with HandlebarType.all
      end
    end
  end
end