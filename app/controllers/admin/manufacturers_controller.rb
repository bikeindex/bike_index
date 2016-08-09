class Admin::ManufacturersController < Admin::BaseController
  before_filter :find_manufacturer, only: [:edit, :update, :destroy, :show]

  def index
    @manufacturers = Manufacturer.all
  end

  def show
    raise ActionController::RoutingError.new('Not Found') unless @manufacturer.present?
    @manufacturer = @manufacturer.decorate
  end

  def new
    @manufacturer = Manufacturer.new
  end

  def edit
  end

  def update
    if @manufacturer.update_attributes(permitted_parameters)
      flash[:success] = 'Manufacturer Saved!'
      expire_fragment 'header_search'
      AutocompleteLoaderWorker.perform_async('load_manufacturers')
      redirect_to admin_manufacturer_url(@manufacturer)
    else
      render action: :edit
    end
  end

  def create
    @manufacturer = Manufacturer.create(permitted_parameters)
    if @manufacturer.save
      flash[:success] = 'Manufacturer Created!'
      expire_fragment 'header_search'
      AutocompleteLoaderWorker.perform_async('load_manufacturers')
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
      flash[:success] = 'Manufacturers imported'
      redirect_to admin_manufacturers_url
    else
      flash[:notice] = 'You gotta choose a file to import!'
      redirect_to admin_manufacturers_url
    end
  end

  protected

  def permitted_parameters
    params.require(:manufacturer).permit(Manufacturer.old_attr_accessible)
  end

  def find_manufacturer
    @manufacturer = Manufacturer.friendly_find(params[:id])
    raise ActionController::RoutingError.new('Not Found') unless @manufacturer.present?
  end
end
