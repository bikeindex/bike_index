class ManufacturersController < ApplicationController
  layout 'content'
  before_filter :set_manufacturers_active_section

  def index
    @title = "Manufacturers"
    @manufacturers = Manufacturer.all
    respond_to do |format|
      format.html
      format.csv { render text: @manufacturers.to_csv }
    end
  end

  def mock_csv
    @title = "Manufacturers csv"
    @manufacturers = Manufacturer.all
    render layout: false
  end

  def show
    manufacturer = Manufacturer.find_by_slug(params[:id])
    @manufacturer = manufacturer.decorate
    @title = manufacturer.name
  end

  def set_manufacturers_active_section
    @active_section = "resources"
  end

end
