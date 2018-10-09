class Admin::UsersController < Admin::BaseController
  before_filter :find_user, only: [:edit, :update, :destroy]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 25
    if params[:user_query].present?
      users = User.admin_text_search(params[:user_query])
      @users = Kaminari.paginate_array(users).page(page).per(per_page)
    else
      if params[:superusers]
        users = User.where(superuser: true)
      elsif params[:content_admins]
        users = User.where(is_content_admin: true)
      else 
        users = User.order("created_at desc")
      end
      @users = users.page(page).per(per_page)
    end
    @user_count = users.count
  end

  def show
    redirect_to edit_admin_user_url
  end

  def edit
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @bikes = @user.bikes.page(page).per(per_page)
    @ownerships = @user.ownerships.page(page).per(per_page)
  end

  def update
    @user.name = params[:user][:name]
    @user.email = params[:user][:email]
    @user.superuser = params[:user][:superuser]
    @user.developer = params[:user][:developer] if current_user.developer
    @user.is_content_admin = params[:user][:is_content_admin]
    @user.banned = params[:user][:banned]
    @user.username = params[:user][:username]
    @user.can_send_many_stolen_notifications = params[:user][:can_send_many_stolen_notifications]
    if @user.save
      @user.confirm(@user.confirmation_token) if params[:user][:confirmed]
      redirect_to admin_users_url, notice: 'User Updated'
    else
      bikes = @user.bikes
      @bikes = BikeDecorator.decorate_collection(bikes)
      render action: :edit
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_url, notice: 'User Deleted.'
  end
  

  protected

  def find_user
    user_id = params[:id]
    if user_id.is_a?(Integer) || user_id.match(/\A\d*\z/).present?
      @user = User.where(id: user_id).first
    end
    @user ||= User.find_by_username(user_id)
    raise ActionController::RoutingError.new('Not Found') unless @user.present?
  end
end
