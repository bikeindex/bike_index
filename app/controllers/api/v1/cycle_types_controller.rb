module Api
  module V1
    class CycleTypesController < ApiV1Controller
      def index
        respond_with CycleType.all
      end
    end
  end
end