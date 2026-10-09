class LandingPagesController < ApplicationController
  before_action :force_html_response
  before_action :instantiate_feedback, except: [:show]

  def show
    raise ActionController::RoutingError, "Not found" unless current_organization.present?
  end

  def for_community_groups
    total_bikes, recoveries_count, recoveries_value, organizations_count =
      Counts.retrieve_many("total_bikes", "recoveries", "recoveries_value", "organizations")

    organization_path = new_organization_path(kind: "bike_advocacy")
    sign_up_path = current_user.present? ? organization_path : new_user_path(return_to: organization_path)

    render Pages::LandingPages::ForCommunityGroups::Component.new(recovery_displays: RecoveryDisplay.with_photo.limit(3),
      total_bikes:, recoveries_count:, recoveries_value:, organizations_count:, sign_up_path:)
  end

  protected

  def instantiate_feedback
    @feedback ||= Feedback.new
  end
end
