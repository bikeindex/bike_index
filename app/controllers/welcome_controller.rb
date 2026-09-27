class WelcomeController < ApplicationController
  before_action :force_html_response
  before_action :authenticate_user_for_welcome_controller, only: [:choose_registration]
  # Allow iframes on the index URL because safari is an asshole, and doesn't honor our iframe options
  before_action :allow_x_frame, only: [:bike_creation_graph, :index]

  def index
    @recovery_displays = RecoveryDisplay.with_photo.limit(10)
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
    @pagy, @recovery_displays = pagy(:countish, RecoveryDisplay.with_attached_photo_processed,
      limit: permitted_per_page(default: Pages::RecoveryStories::Index::Component::PER_PAGE), page: permitted_page)

    flash.now[:notice] = translation(:no_stories_to_display) if @recovery_displays.empty?
    total_bikes, recoveries_count, recoveries_value, organizations_count =
      Counts.retrieve_many("total_bikes", "recoveries", "recoveries_value", "organizations")

    render Pages::RecoveryStories::Index::Component.new(recovery_displays: @recovery_displays, pagy: @pagy,
      total_bikes:, recoveries_count:, recoveries_value:, organizations_count:, currency: current_currency)
  end

  # Adding for testing purposes - so we can test where the root url for a user goes - sethherr, 2019-7-9
  def user_root_url_redirect
    redirect_to(user_root_url) && return
  end

  private

  def authenticate_user_for_welcome_controller
    authenticate_user(translation_key: :create_account, flash_type: :notice, sign_up_not_in: true)
  end
end
