class ManufacturersController < ApplicationController
  def index
    @manufacturers = Manufacturer.all
    respond_to do |format|
      format.html
      format.csv { render plain: @manufacturers.to_csv }
    end
  end

  def tsv
    redirect_to "https://files.bikeindex.org/uploads/tsvs/manufacturers.tsv"
  end
end
