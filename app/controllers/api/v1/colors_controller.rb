module Api
  module V1
    class ColorsController < ApiV1Controller
      def index
        respond_with Color.all
      end
    end
  end
end