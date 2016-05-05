class Admin::OwnershipsController < Admin::BaseController

  def edit
    @ownership = Ownership.find(params[:id])
    @bike = Bike.unscoped.find(@ownership.bike_id).decorate 
    @users = User.all
  end

  def update
    @ownership = Ownership.find(params[:id])
    if params[:ownership]
      if params[:ownership][:user_email].present?
        params[:ownership][:user_id] = User.fuzzy_id(params[:ownership].delete(:user_email)) 
      end
      if params[:ownership][:creator_email].present?
        params[:ownership][:creator_id] = User.fuzzy_id(params[:ownership].delete(:creator_email))
      end
    end
    if @ownership.update_attributes(params[:ownership])
      flash[:success] = "Ownership Saved!"
      redirect_to edit_admin_ownership_url(@ownership.id)
    else
      render action: :edit
    end
  end

end
