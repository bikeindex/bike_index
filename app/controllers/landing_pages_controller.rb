class LandingPagesController < ApplicationController
  before_action :force_html_response
  before_action :instantiate_feedback, except: %i[show for_community_groups]

  def show
    raise ActionController::RoutingError, "Not found" unless current_organization.present?
  end

  def for_community_groups
    render SharedBlocks::Marketing::Wrapper::Component.new(page: Pages::LandingPages::ForCommunityGroups::Component.new(
      recovery_displays: RecoveryDisplay.with_photo.limit(4),
      sign_up_path: new_organization_signup_path(kind: "bike_advocacy")
    ))
  end

  protected

  def instantiate_feedback
    @feedback ||= Feedback.new(email: current_user&.email, contact_name: current_user&.name)
  end
end
