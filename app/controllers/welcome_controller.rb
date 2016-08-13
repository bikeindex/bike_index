class WelcomeController < ApplicationController
  layout 'application_revised'
  before_filter :authenticate_user_for_welcome_controller, only: [:user_home, :choose_registration]

  def index
  end

  def update_browser
    render action: 'update_browser', layout: false
  end

  def goodbye
    redirect_to logout_url and return if current_user.present?
  end

  def user_home
    bikes = current_user.bikes
    page = params[:page] || 1
    @per_page = params[:per_page] || 20
    paginated_bikes = Kaminari.paginate_array(bikes).page(page).per(@per_page)
    @bikes = BikeDecorator.decorate_collection(paginated_bikes)
    @locks = LockDecorator.decorate_collection(current_user.locks)
  end

  def choose_registration
  end

  private

  def authenticate_user_for_welcome_controller
    authenticate_user('Please create an account', flash_type: :info)
  end
end
