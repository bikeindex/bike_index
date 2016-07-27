class Admin::OwnershipsController < Admin::BaseController
  before_filter :find_ownership

  def edit
  end

  def update
    if params[:ownership]
      if params[:ownership][:user_email].present?
        params[:ownership][:user_id] = User.friendly_id_find(params[:ownership].delete(:user_email)) 
      end
      if params[:ownership][:creator_email].present?
        params[:ownership][:creator_id] = User.friendly_id_find(params[:ownership].delete(:creator_email))
      end
    end
    if params[:ownership] && @ownership.update_attributes(permitted_parameters) 
      flash[:success] = 'Ownership Saved!'
      redirect_to edit_admin_ownership_url(@ownership.id)
    else
      flash[:info] = 'No information updated'
      render action: :edit
    end
  end

  private

  def find_ownership
    @ownership = Ownership.find(params[:id])
    @bike = Bike.unscoped.find(@ownership.bike_id).decorate 
    @users = User.all
  end

  def permitted_parameters
    params.require(:ownership).permit(Ownership.old_attr_accessible)
  end
end
