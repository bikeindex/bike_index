class Admin::FlavorTextsController < Admin::BaseController

  def create
    @flavor_text = FlavorText.new(params[:flavor_text])
    if @flavor_text.save
      flash[:notice] = "Flavor Created!"
      redirect_to admin_root_url
    else
      redirect_to admin_root_url
    end
  end

  def destroy
    @flavor_text = FlavorText.find(params[:id])
    @flavor_text.destroy
    flash[:notice] = "Flavor destroyed"
    redirect_to admin_root_url
  end


end
