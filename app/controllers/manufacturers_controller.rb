class ManufacturersController < ApplicationController
  def index
    @manufacturers = Manufacturer.except_other

    respond_to do |format|
      format.html
      format.csv { render plain: Spreadsheets::Manufacturers.to_csv(@manufacturers) }
    end
  end
end
