require "rails_helper"

RSpec.describe Organized::RecoveriesController, type: :request do
  let(:base_url) { "/o/#{current_organization.to_param}/recoveries" }
  include_context :request_spec_logged_in_as_organization_user
  let(:enabled_feature_slugs) { %w[show_recoveries] }
  let(:current_organization) do
    FactoryBot.create(:organization_with_organization_features, :in_nyc, enabled_feature_slugs:)
  end

  let(:nyc_bike) { FactoryBot.create(:stolen_bike_in_nyc, year: 2019) }
  let(:chicago_bike) { FactoryBot.create(:stolen_bike_in_chicago) }
  let!(:nyc_record) { recover(nyc_bike, 2.days.ago) }
  let!(:chicago_record) { recover(chicago_bike, 2.years.ago) }

  define_method(:recover) do |bike, recovered_at|
    stolen_record = bike.fetch_current_stolen_record
    stolen_record.add_recovery_information(recovered_at: recovered_at.to_s)
    stolen_record.reload
  end

  it "renders the nearby recoveries, newest first" do
    expect(current_organization.reload.search_coordinates_set?).to be_truthy
    get base_url
    expect(response.status).to eq 200
    expect(response.body).to include("Recoveries")
    expect(response.body).to match(%r{>1</span> match\b})
    expect(response.body).to include("2019 #{nyc_bike.mnfg_name}")
    expect(response.body).not_to include(chicago_bike.frame_model_truncated) if chicago_bike.frame_model.present?
    expect(response.body).to include("/o/#{current_organization.to_param}/registrations")
  end

  context "with a recovery in the bounding box's corner" do
    let(:corner_bike) { FactoryBot.create(:stolen_bike) }

    it "leaves it out, since it's past the radius" do
      latitude, longitude = current_organization.reload.search_coordinates
      # ~4.1 mi north and ~4.2 mi east: inside a 5 mile box, ~5.9 mi away
      recover(corner_bike, 1.day.ago).update_columns(latitude: latitude + 0.06, longitude: longitude + 0.08)

      get base_url, params: {search_distance: 5}
      expect(response.body).to match(%r{>1</span> match\b})

      get base_url, params: {search_distance: 10}
      expect(response.body).to match(%r{>2</span> matches\b})
    end
  end

  context "with a bike registered with the organization" do
    before { FactoryBot.create(:bike_organization, bike: chicago_bike, organization: current_organization) }

    it "shows only the organization's, at any distance, and filters by period" do
      get base_url, params: {search_only_organization: 1, search_result_view: "table"}
      expect(response.status).to eq 200
      expect(response.body).to match(%r{>1</span> match\b})
      expect(response.body).to include(chicago_bike.mnfg_name)

      get base_url, params: {search_only_organization: 1, period: "year"}
      expect(response.body).to include("Try a wider date range.")

      get base_url, params: {search_distance: 5, period: "year", search_result_view: "cards"}
      expect(response.body).to match(%r{>1</span> match\b})
    end
  end

  context "without show_recoveries" do
    let(:enabled_feature_slugs) { [] }

    it "redirects" do
      get base_url
      expect(response).to redirect_to(organization_registrations_path(organization_id: current_organization.to_param))
    end
  end

  it "redirects the old path" do
    get "/o/#{current_organization.to_param}/bikes/recoveries"
    expect(response).to redirect_to(base_url)
  end
end
