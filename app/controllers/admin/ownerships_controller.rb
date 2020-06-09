class Admin::OwnershipsController < Admin::BaseController
  before_action :find_ownership

  def edit
  end

  def update
    error_message = []
    if params[:ownership]
      if params[:ownership][:user_email].present?
        params[:ownership][:user_id] = User.friendly_id_find(params[:ownership].delete(:user_email))
        error_message << "No confirmed user with that User email!" unless params[:ownership][:user_id].present?
      end
      if params[:ownership][:creator_email].present?
        params[:ownership][:creator_id] = User.friendly_id_find(params[:ownership].delete(:creator_email))
        error_message << "No confirmed user with creator email!" unless params[:ownership][:creator_id].present?
      end
    end
    if error_message.blank? && params[:ownership].present? && @ownership.update_attributes(permitted_parameters)
      flash[:success] = "Ownership Saved!"
      redirect_to edit_admin_ownership_url(@ownership.id)
    else
      if error_message.present?
        flash[:error] = error_message.join(" ")
      else
        flash[:info] = "No information updated"
      end
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
    params.require(:ownership).permit(:bike_id, :user_id, :owner_email, :creator_id, :current, :claimed, :example, :send_email, :user_hidden)
  end
end
