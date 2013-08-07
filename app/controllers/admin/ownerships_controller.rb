class Admin::OwnershipsController < Admin::BaseController

  def edit
    @ownership = Ownership.find(params[:id])
    @bike = @ownership.bike.decorate 
    @users = User.all
  end

  def update
    @ownership = Ownership.find(params[:id])
    if @ownership.update_attributes(params[:ownership])
      flash[:notice] = "Ownership Saved!"
      redirect_to edit_admin_bike_url(@ownership.bike)
    else
      render action: :edit
    end
  end


  # def destroy
  #   @bike = @ownership.bike
  #   @ownership.destroy
  #   redirect_to admin_bike_url(@bike)
  # end

end
