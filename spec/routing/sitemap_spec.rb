require "rails_helper"

RSpec.describe "Sitemaps pages" do
  it "includes non-info/landing controller pages" do
    target_info_paths = %w[help donate why-donate]
    expect((SitemapPages::INFORMATION & target_info_paths).count).to eq target_info_paths.count

    target_additional_paths = %w[recovery_stories documentation/api_v3 where]
    expect((SitemapPages::ADDITIONAL & target_additional_paths).count).to eq target_additional_paths.count
  end

  context "with parsed routes" do
    let(:all_app_routes) do
      Rails.application.routes.routes.collect { |route|
        ActionDispatch::Routing::RouteWrapper.new(route)
      }.reject(&:internal?)
    end
    let(:info_routes) { all_app_routes.select { |r| r.controller == "info" }.map { |r| to_formatted_path(r) } }
    let(:landing_pages_routes) { all_app_routes.select { |r| r.controller == "landing_pages" }.map { |r| to_formatted_path(r) } }
    let(:excluded_routes) do
      ["support_bike_index", "support_the_index", "support_the_bike_index", "info/:id", "primary_activities",
        "info/how-to-get-your-stolen-bike-back", "ikes", "university"]
    end

    def to_formatted_path(route)
      route.path.gsub("(.:format)", "").delete_prefix("/")
    end

    it "includes all the info and landing page routes" do
      missing_info_paths = info_routes - excluded_routes - SitemapPages::INFORMATION - SitemapPages::ADDITIONAL
      expect(missing_info_paths).to eq([])

      missing_landing_paths = landing_pages_routes - excluded_routes - SitemapPages::INFORMATION - SitemapPages::ADDITIONAL
      expect(missing_landing_paths).to eq([])
    end
  end
end
