class Admin::CtypesController < Admin::BaseController
  before_filter :find_ctypes, only: [:edit, :update, :destroy]  

  def index
    @ctypes = Ctype.all
  end

  def new
    @ctype = Ctype.new
  end

  def edit
  end

  def update
    if @ctype.update_attributes(params[:ctype])
      flash[:success] = 'Component Type Saved!'
      redirect_to admin_ctypes_url
    else
      render action: :edit
    end
  end

  def create
    @ctype = Ctype.create(params[:ctype])
    if @ctype.save
      flash[:success] = 'Component type created!'
      redirect_to admin_ctypes_url
    else
      render action: :new
    end
  end

  def destroy
    @ctype.destroy
    redirect_to admin_ctypes_url
  end


  def import
    Ctype.import(params[:file])
    flash[:success] = 'Component types imported'
    redirect_to admin_ctypes_url
  end

  protected

  def find_ctypes
    @ctype = Ctype.find_by_slug(params[:id])
    raise ActionController::RoutingError.new('Not Found') unless @ctype.present?
  end
end
