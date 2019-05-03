class Admin::ManufacturersController < Admin::BaseController
  include SortableTable
  before_filter :find_manufacturer, only: [:edit, :update, :destroy, :show]
  layout "new_admin"

  def index
    @manufacturers = Manufacturer.reorder("manufacturers.#{sort_column} #{sort_direction}")
  end

  def show
    raise ActionController::RoutingError.new("Not Found") unless @manufacturer.present?
    @manufacturer = @manufacturer.decorate
  end

  def new
    @manufacturer = Manufacturer.new
  end

  def edit
  end

  def update
    if @manufacturer.update_attributes(permitted_parameters)
      flash[:success] = "Manufacturer Saved!"
      expire_fragment "header_search"
      AutocompleteLoaderWorker.perform_async("load_manufacturers")
      redirect_to admin_manufacturer_url(@manufacturer)
    else
      render action: :edit
    end
  end

  def create
    @manufacturer = Manufacturer.create(permitted_parameters)
    if @manufacturer.save
      flash[:success] = "Manufacturer Created!"
      expire_fragment "header_search"
      AutocompleteLoaderWorker.perform_async("load_manufacturers")
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
      flash[:success] = "Manufacturers imported"
      redirect_to admin_manufacturers_url
    else
      flash[:notice] = "You gotta choose a file to import!"
      redirect_to admin_manufacturers_url
    end
  end

  protected

  def sortable_columns
    %w[name created_at frame_maker]
  end

  def default_direction # So it can be overridden
    "asc"
  end

  def permitted_parameters
    params.require(:manufacturer).permit(:name, :slug, :website, :frame_maker, :total_years_active, :notes, :open_year, :close_year, :logo, :description, :logo_source)
  end

  def find_manufacturer
    @manufacturer = Manufacturer.friendly_find(params[:id])
    raise ActionController::RoutingError.new("Not Found") unless @manufacturer.present?
  end
end
