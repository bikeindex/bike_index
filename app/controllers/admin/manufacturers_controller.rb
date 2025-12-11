class Admin::ManufacturersController < Admin::BaseController
  include SortableTable

  before_action :find_manufacturer, only: [:edit, :update, :destroy, :show]

  def index
    @manufacturers = searched_manufacturers.reorder("manufacturers.#{sort_column} #{sort_direction}")
  end

  def show
    raise ActionController::RoutingError.new("Not Found") unless @manufacturer.present?
  end

  def new
    @manufacturer = Manufacturer.new
  end

  def edit
  end

  def update
    if @manufacturer.update(permitted_parameters)
      flash[:success] = "Manufacturer Saved!"
      AutocompleteLoaderJob.perform_async
      redirect_to admin_manufacturer_url(@manufacturer)
    else
      render action: :edit
    end
  end

  def create
    @manufacturer = Manufacturer.create(permitted_parameters)
    if @manufacturer.save
      flash[:success] = "Manufacturer Created!"
      AutocompleteLoaderJob.perform_async
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
    else
      flash[:notice] = "You gotta choose a file to import!"
    end
    redirect_to admin_manufacturers_url
  end

  protected

  def sortable_columns
    %w[name created_at frame_maker priority motorized_only]
  end

  def default_direction
    "asc"
  end

  def permitted_parameters
    params.require(:manufacturer).permit(:name, :slug, :website, :frame_maker,
      :motorized_only, :total_years_active, :notes, :open_year,
      :close_year, :logo, :description, :logo_source, :twitter_name)
  end

  def searched_manufacturers
    manufacturers = Manufacturer
    @with_logos = BinxUtils::InputNormalizer.boolean(params[:search_with_logos])
    manufacturers = manufacturers.with_websites if @with_logos
    @with_websites = BinxUtils::InputNormalizer.boolean(params[:search_with_websites])
    manufacturers = manufacturers.with_logos if @with_logos
    manufacturers
  end

  def find_manufacturer
    @manufacturer = Manufacturer.friendly_find(params[:id])
    raise ActionController::RoutingError.new("Not Found") unless @manufacturer.present?
  end
end
