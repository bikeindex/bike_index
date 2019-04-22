class WelcomeController < ApplicationController
  layout 'application_revised'
  before_action :force_html_response
  before_filter :authenticate_user_for_welcome_controller, only: [:user_home, :choose_registration]
  # Allow iframes on the index URL because safari is an asshole, and doesn't honor our iframe options
  skip_before_filter :set_x_frame_options_header, only: [:bike_creation_graph, :index]

  def index
    @recovery_displays = RecoveryDisplay.limit(5)
  end

  def bike_creation_graph
    @height = (params[:height] || 300).to_i
    render layout: false
  end

  def update_browser
    render action: 'update_browser', layout: false
  end

  def goodbye
    redirect_to logout_url and return if current_user_or_unconfirmed_user.present?
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

  def recovery_stories
    page = params[:page] || 1
    @per_page = params[:per_page] || 10
    @recovery_displays = RecoveryDisplay.page(page).per(@per_page)
    @slice1, @slice2 = list_halves(@recovery_displays)
  end

  private

  def authenticate_user_for_welcome_controller
    authenticate_user('Please create an account', flash_type: :info)
  end

  def list_halves(list)
    slice_size = (list.length / 2.0).ceil
    slice1, slice2 = list.each_slice(slice_size).entries
    [slice1, slice2 || []]
  end
end
