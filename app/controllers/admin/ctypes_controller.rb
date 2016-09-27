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
    if @ctype.update_attributes(permitted_parameters)
      flash[:success] = 'Component Type Saved!'
      redirect_to admin_ctypes_url
    else
      render action: :edit
    end
  end

  def create
    @ctype = Ctype.create(permitted_parameters)
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

  def permitted_parameters
    params.require(:ctype).permit(Ctype.old_attr_accessible)
  end

  def find_ctypes
    @ctype = Ctype.friendly_find(params[:id])
    raise ActionController::RoutingError.new('Not Found') unless @ctype.present?
  end
end
