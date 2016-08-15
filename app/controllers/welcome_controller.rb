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
    @locks_active_tab = params[:active_tab] == 'locks'
    @per_page = params[:per_page] || 20
    paginated_bikes = Kaminari.paginate_array(bikes).page(page).per(@per_page)
    @bikes = BikeDecorator.decorate_collection(paginated_bikes)
    @locks = LockDecorator.decorate_collection(current_user.locks)
  end

    # @variable that is first display whether bikes or locks
    # in locks controller, after add lock, send you to user home w/ first display locks
    # and should function first displaying locks
    # make locks into table > look at manufacturers page
    # make locks edit/new page use the revised view
    # remove show and it's link. add edit link

  # add old styles, translations search for classes
  # add photo to lock table?
  def choose_registration
  end

  private

  def authenticate_user_for_welcome_controller
    authenticate_user('Please create an account', flash_type: :info)
  end
end
