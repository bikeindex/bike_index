class LandingPagesController < ApplicationController
  before_action :force_html_response
  before_action :instantiate_feedback, only: %i[bike_shop_packages for_cities for_law_enforcement for_schools]

  def show
    raise ActionController::RoutingError, "Not found" unless current_organization.present?
  end

  def for_bike_shops
    render SharedBlocks::Marketing::Wrapper::Component.new(page: Pages::LandingPages::ForBikeShops::Component.new(
      recovery_displays: RecoveryDisplay.where.not(quote_by: [nil, ""]), current_user:,
      checker_place: EbikeRuleServices::Places.from_location(request_location_hash)
    ))
  end

  def for_community_groups
    render SharedBlocks::Marketing::Wrapper::Component.new(page: Pages::LandingPages::ForCommunityGroups::Component.new(
      recovery_displays: RecoveryDisplay.with_photo.limit(4),
      sign_up_path: new_organization_signup_path(kind: "bike_advocacy")
    ))
  end

  def ascend
    render SharedBlocks::Marketing::Wrapper::Component.new(page: Pages::LandingPages::Ascend::Component.new(
      has_shop: current_user&.has_shop_organization_role?
    ))
  end

  protected

  def instantiate_feedback
    @feedback ||= Feedback.new(email: current_user&.email, contact_name: current_user&.name)
  end
end
