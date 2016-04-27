class ManufacturersController < ApplicationController
  layout 'content'
  before_filter :set_manufacturers_active_section
  before_filter :set_revised_layout

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

  def set_manufacturers_active_section
    @active_section = 'resources'
  end
end
