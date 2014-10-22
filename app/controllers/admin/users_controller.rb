class Admin::UsersController < Admin::BaseController
  before_filter :find_user, only: [:show, :edit, :update, :destroy]

  def index
    if params[:user_query]
      # if params[:email]
      users = User.admin_text_search(params[:user_query])
      # users = User.where('email LIKE ?', params[:user_query]).all
      # users += User.where('name LIKE ?', params[:user_query]).all
      # @users = users
    else 
      users = User.order("created_at desc")
    end
    @users = users.paginate(page: params[:page]).per_page(50)
  end

  def edit
    bikes = Bike.unscoped.find(@user.bikes)
    @bikes = BikeDecorator.decorate_collection(bikes)
  end

  def update
    @membership = Membership.new
    @user.name = params[:user][:name]
    @user.email = params[:user][:email]
    @user.confirmed = params[:user][:confirmed]
    @user.superuser = params[:user][:superuser]
    @user.can_invite = params[:user][:can_invite]
    @user.banned = params[:user][:banned]
    @user.username = params[:user][:username]
    @user.can_send_many_stolen_notifications = params[:user][:can_send_many_stolen_notifications]
    # m = Membership.new
    # .membership = params[:user][:organizations]

    # @membership = Membership.new(params[:membership])
    # @membership.organization_id = params[:user][:organizations]
    # # @user.organization_role = params[:user][:organization_role]
    if @user.save
      redirect_to admin_users_url, notice: 'User Updated'
    else
      bikes = Bike.find(@user.bikes)
      @bikes = BikeDecorator.decorate_collection(bikes)
      render action: :edit
    end
  end

  def bike_tokens
    @user = User.find(params[:user_id])
  end

  def add_bike_tokens
    @user = User.find(params[:user_id])
    if params[:count].present? and params[:organization_id].present?
      params[:count].to_i.times do
        bt = BikeToken.new
        bt.user = @user
        bt.organization = Organization.find(params[:organization_id])
        bt.save!
      end
    else
      render action: :bike_tokens
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_url, notice: 'User Deleted.'
  end
  

  protected

  def find_user
    @user = User.find_by_username(params[:id])
    raise ActionController::RoutingError.new('Not Found') unless @user.present?
  end

end
