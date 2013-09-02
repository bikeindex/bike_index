module Api
  module V1
    class FrameMaterialsController < ApiV1Controller
      def index
        respond_with FrameMaterial.all
      end
    end
  end
end