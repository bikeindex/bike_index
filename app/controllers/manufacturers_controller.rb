class ManufacturersController < ApplicationController
  def index
    @manufacturers = Manufacturer.all
    respond_to do |format|
      format.html
      format.csv { render plain: Spreadsheets::Manufacturer.to_csv(@manufacturers) }
    end
  end
end
