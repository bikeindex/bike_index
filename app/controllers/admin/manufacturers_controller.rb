class Admin::ManufacturersController < Admin::BaseController
  before_filter :find_manufacturer, only: [:edit, :update, :destroy]  

  def index
    @manufacturers = Manufacturer.all
  end

  def show
    manufacturer = Manufacturer.find_by_slug(params[:id])
    @manufacturer = manufacturer.decorate
  end

  def new
    @manufacturer = Manufacturer.new
  end

  def edit
  end

  def update
    if @manufacturer.update_attributes(params[:manufacturer])
      flash[:notice] = "Manufacturer Saved!"
      redirect_to admin_manufacturer_url(@manufacturer)
    else
      render action: :edit
    end
  end

  def create
    @manufacturer = Manufacturer.create(params[:manufacturer])
    if @manufacturer.save
      flash[:notice] = "Manufacturer Created!"
      redirect_to admin_manufacturer_url(@manufacturer)
    else
      render action: :new
    end
  end

  def destroy
    @manufacturer.destroy
    redirect_to admin_manufacturers_url
  end


  def import
    if params[:file]
      Manufacturer.import(params[:file])
      flash[:notice] = "Manufacturers imported"
      redirect_to admin_manufacturers_url
    else
      flash[:notice] = "You gotta choose a file to import!"
      redirect_to admin_manufacturers_url
    end
  end

  protected

  def find_manufacturer
    @manufacturer = Manufacturer.find_by_slug(params[:id])
  end
end
