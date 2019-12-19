class WelcomeController < ApplicationController
  before_action :force_html_response
  before_action :authenticate_user_for_welcome_controller, only: [:user_home, :choose_registration]
  # Allow iframes on the index URL because safari is an asshole, and doesn't honor our iframe options
  skip_before_action :set_x_frame_options_header, only: [:bike_creation_graph, :index]

  def index
    @recovery_displays = RecoveryDisplay.limit(5)
  end

  def bike_creation_graph
    @height = (params[:height] || 300).to_i
    render layout: false
  end

  def update_browser
    render action: "update_browser", layout: false
  end

  def goodbye
    redirect_to logout_url and return if current_user_or_unconfirmed_user.present?
  end

  def user_home
    page = params[:page] || 1
    @locks_active_tab = params[:active_tab] == "locks"
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
    @per_page = params[:per_page] || 50

    @recovery_displays = RecoveryDisplay.page(page).per(@per_page)
    @slice1, @slice2 = list_halves(@recovery_displays)

    flash[:notice] = translation(:no_stories_to_display) if @recovery_displays.empty?
  end

  # Adding for testing purposes - so we can test where the root url for a user goes - sethherr, 2019-7-9
  def user_root_url_redirect; redirect_to user_root_url and return end

  private

  def authenticate_user_for_welcome_controller
    authenticate_user(translation_key: :create_account, flash_type: :info)
  end

  # Split the given array `list` into two halves
  # Return a tuple with each half as an array.
  def list_halves(list)
    return [[], []] if list.empty?

    slice_size = (list.length / 2.0).ceil
    slice1, slice2 = list.each_slice(slice_size).entries
    [slice1, slice2 || []]
  end
end
