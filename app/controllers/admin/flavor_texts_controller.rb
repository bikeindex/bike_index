class Admin::FlavorTextsController < Admin::BaseController

  def create
    @flavor_text = FlavorText.new(permitted_parameters)
    if @flavor_text.save
      flash[:success] = "Flavor Created!"
      redirect_to admin_root_url
    else
      redirect_to admin_root_url
    end
  end

  def destroy
    @flavor_text = FlavorText.find(params[:id])
    @flavor_text.destroy
    flash[:success] = "Flavor destroyed"
    redirect_to admin_root_url
  end

  def permitted_parameters
    params.require(:flavor_text).permit(FlavorText.old_attr_accessible)
  end
end
