module Api
  module V2
    class ManufacturersController < ApiV2Controller

      def index
        manufacturers = Manufacturer.all
        respond_with manufacturers
      end

      def show
        if params[:id].match(/\A\d*\z/).present?
          manufacturer = Manufacturer.find(params[:id])
        else
          manufacturer = Manufacturer.fuzzy_name_find(params[:id])
        end
        raise ActiveRecord::RecordNotFound unless manufacturer.present?
        respond_with manufacturer
      end

    end
  end
end
