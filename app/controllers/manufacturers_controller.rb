class ManufacturersController < ApplicationController
  layout 'content'
  before_filter :set_manufacturers_active_section

  def index
    @manufacturers = Manufacturer.all
    respond_to do |format|
      format.html
      format.csv { render text: @manufacturers.to_csv }
    end
  end

  def tsv
    redirect_to 'https://files.bikeindex.org/uploads/tsvs/manufacturers.tsv'
  end

  def show
    manufacturer = Manufacturer.find_by_slug(params[:id])
    raise ActionController::RoutingError.new('Not Found') unless manufacturer.present?
    @manufacturer = manufacturer.decorate
  end

  def set_manufacturers_active_section
    @active_section = "resources"
  end

end
