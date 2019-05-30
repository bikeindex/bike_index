class LandingPagesController < ApplicationController
  layout "application_revised"
  before_action :force_html_response
  before_filter :instantiate_feedback, except: [:show]

  def show
    raise ActionController::RoutingError, "Not found" unless current_organization.present?
  end

  def for_shops; end

  def for_advocacy; redirect_to(for_community_groups_path); end

  def for_community_groups; end

  def for_law_enforcement; end

  def for_schools; end

  def ascend; @page_title ||= "Ascend POS on Bike Index" end

  def ambassadors_current; @page_title ||= "Current Ambassadors" end

  def ambassadors_how_to; @page_title ||= "Ambassadors" end

  def bike_shop_packages; @page_title ||= "Features & Pricing: Bike Shops"; end

  def campus_packages; @page_title ||= "Features & Pricing: Schools"; end

  def cities_packages; @page_title ||= "Features & Pricing: Cities"; end

  protected

  def instantiate_feedback
    @feedback ||= Feedback.new
  end
end
