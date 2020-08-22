class WelcomeController < ApplicationController
  before_action :force_html_response
  before_action :authenticate_user_for_welcome_controller, only: [:choose_registration]
  # Allow iframes on the index URL because safari is an asshole, and doesn't honor our iframe options
  before_action :permit_cross_site_iframe!, only: [:bike_creation_graph, :index]

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
    redirect_to(logout_url) && return if current_user_or_unconfirmed_user.present?
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
  def user_root_url_redirect
    redirect_to(user_root_url) && return
  end

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
