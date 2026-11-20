class LandingPagesController < ApplicationController
  before_action :force_html_response
  before_action :instantiate_feedback, except: %i[show for_community_groups ascend]

  def show
    raise ActionController::RoutingError, "Not found" unless current_organization.present?
  end

  def for_community_groups
    organization_path = new_organization_path(kind: "bike_advocacy")
    sign_up_path = current_user.present? ? organization_path : new_user_path(return_to: organization_path)

    render SharedBlocks::Marketing::Wrapper::Component.new(page: Pages::LandingPages::ForCommunityGroups::Component.new(
      recovery_displays: RecoveryDisplay.with_photo.limit(4), sign_up_path:
    ))
  end

  def ascend
    render SharedBlocks::Marketing::Wrapper::Component.new(page: Pages::LandingPages::Ascend::Component.new(
      has_shop: current_user&.has_shop_organization_role? || false
    ))
  end

  protected

  def instantiate_feedback
    @feedback ||= Feedback.new(email: current_user&.email, contact_name: current_user&.name)
  end
end
