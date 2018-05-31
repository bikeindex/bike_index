class WelcomeController < ApplicationController
  layout 'application_revised'
  before_filter :authenticate_user_for_welcome_controller, only: [:user_home, :choose_registration]
  # Allow iframes on the index URL because safari is an asshole, and doesn't honor our iframe options
  skip_before_filter :set_x_frame_options_header, only: [:bike_creation_graph, :index]

  def index
  end

  def bike_creation_graph
    @height = (params[:height] || 300).to_i
    render layout: false
  end

  def update_browser
    render action: 'update_browser', layout: false
  end

  def goodbye
    redirect_to logout_url and return if current_user.present?
  end

  def user_home
    page = params[:page] || 1
    @locks_active_tab = params[:active_tab] == 'locks'
    @per_page = params[:per_page] || 20
    # If there are over 100 bikes created by the user, we'll have problems loading and sorting them
    if current_user.creation_states.limit(101).count > 100
      bikes = current_user.rough_approx_bikes.page(page).per(@per_page)
      @bikes = bikes.decorate
    else
      bikes = Kaminari.paginate_array(current_user.bikes).page(page).per(@per_page)
      @bikes = BikeDecorator.decorate_collection(bikes)
    end
    @locks = LockDecorator.decorate_collection(current_user.locks)
  end

  def choose_registration
  end

  private

  def authenticate_user_for_welcome_controller
    authenticate_user('Please create an account', flash_type: :info)
  end
end
