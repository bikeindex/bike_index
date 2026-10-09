require "rails_helper"

RSpec.describe Admin::DuplicateBikesController, type: :request do
  base_url = "/admin/duplicate_bikes"
  include_context :request_spec_logged_in_as_superuser

  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let(:organization) { FactoryBot.create(:organization) }
  let!(:marked_bikes) do
    Array.new(11) do |index|
      FactoryBot.create(:bike_lightspeed_pos, manufacturer:, creation_organization: organization,
        serial_number: "EN 14764", owner_email: "rider#{index}@example.com", created_at: Time.current - (20 - index).days)
    end
  end
  let!(:pair) do
    [FactoryBot.create(:bike_lightspeed_pos, manufacturer:, serial_number: "WTU123456", owner_email: "pair@bikeindex.org", created_at: Time.current - 3.days),
      FactoryBot.create(:bike, :with_ownership, manufacturer:, serial_number: "WTU123456", owner_email: "pair@bikeindex.org", frame_model: "Other model")]
  end
  let(:database) { ActiveRecord::Base.connection_db_config.database }
  let(:cache) { BikeServices::DuplicateReviewFinder.cache }
  let(:cache_key) { BikeServices::DuplicateReviewFinder.cache_key(database) }

  before { cache.write(cache_key, {generated_at: Time.current, groups: BikeServices::DuplicateReviewFinder.groups}) }
  after { cache.delete(cache_key) }

  describe "dashboard" do
    it "shows tentative cues and narrows by them reversibly" do
      get base_url, params: {search_kind: "large_group"}
      expect(response.code).to eq "200"
      expect(assigns(:groups).map { it["record_count"] }).to eq [11]
      expect(response.body).to include("Possible standards marking: EN 14764", "Possible product, part or placeholder code",
        "11 example-domain contacts")
      expect(assigns(:cue_counts)).to include("standard_marking" => 1, "review_contact" => 1, "none" => 0)

      get base_url, params: {search_kind: "large_group", search_cue: "none"}
      expect(assigns(:groups)).to be_empty
      expect(assigns(:queue_groups_count)).to eq 1
      expect(response.body).to include("show all")
    end

    it "sorts groups by size or registration date" do
      groups = BikeServices::DuplicateReviewFinder.groups.select { it["kind"] == "large_group" }
      # Cached largest first, like the query
      cache.write(cache_key, {generated_at: Time.current, groups: [
        groups.first.merge("record_count" => 12, "reference_id" => 0, "first_at" => 2.years.ago, "last_at" => 1.year.ago)
      ] + groups})

      get base_url, params: {search_kind: "large_group"}
      expect(assigns(:groups).map { it["record_count"] }).to eq [12, 11]

      get base_url, params: {search_kind: "large_group", sort: "first_at", direction: "asc"}
      expect(assigns(:groups).map { it["record_count"] }).to eq [12, 11]
      get base_url, params: {search_kind: "large_group", sort: "last_at"}
      expect(assigns(:groups).map { it["record_count"] }).to eq [11, 12]
      expect(response.body).to include("Latest registration")
    end
  end

  describe "show" do
    it "summarizes a large group and filters to one contact" do
      get "#{base_url}/serial", params: {reference_bike_id: marked_bikes.first.id}
      expect(response.code).to eq "200"
      expect(assigns(:bikes_count)).to eq 11
      expect(assigns(:review).contact_groups.size).to eq 11
      expect(response.body).to include("Records by initial contact", "Possible standards marking: EN 14764", "Same on every record")

      get "#{base_url}/serial", params: {reference_bike_id: marked_bikes.first.id, search_contact: 2}
      expect(assigns(:bikes).size).to eq 1
      expect(response.body).to include("Show all 11 records")
    end

    it "lists records oldest first, or newest first on request" do
      get "#{base_url}/serial", params: {reference_bike_id: marked_bikes.first.id}
      expect(assigns(:bikes).first).to eq marked_bikes.first
      expect(response.body).to include("oldest registration first", "Show newest first")

      get "#{base_url}/serial", params: {reference_bike_id: marked_bikes.first.id, sort: "created_at", direction: "desc"}
      expect(assigns(:bikes).first).to eq marked_bikes.last
      expect(response.body).to include("newest registration first", "Show oldest first")
    end

    it "compares two records side by side" do
      get "#{base_url}/serial", params: {reference_bike_id: pair.last.id}
      expect(response.code).to eq "200"
      expect(assigns(:reference_bike)).to eq pair.last
      expect(assigns(:review).differing_fields).to include("Model")
      expect(response.body).to include("Initial vs reference", "Differs")
      expect(response.body).to_not include("Do not merge")
    end

    it "flags a placeholder serial as not a duplicate match" do
      placeholders = Array.new(2) { FactoryBot.create(:bike, :with_ownership, manufacturer:, serial_number: "To be specified") }
      get "#{base_url}/compare", params: {bike_ids: placeholders.map(&:id).join(",")}
      expect(response.code).to eq "200"
      expect(response.body).to include("Not a duplicate match: this serial is a placeholder (TO BE SPECIFIED)", "Not a candidate")
    end

    it "treats a manufacturer name typed as the serial as a placeholder" do
      brand = FactoryBot.create(:manufacturer, name: "Motobecane")
      placeholders = Array.new(2) { FactoryBot.create(:bike, :with_ownership, manufacturer: brand, serial_number: "MOTOBECANE") }
      get "#{base_url}/compare", params: {bike_ids: placeholders.map(&:id).join(",")}
      expect(response.body).to include("this serial is a placeholder (manufacturer name Motobecane)")
      expect(BikeServices::DuplicateReviewFinder.groups.find { it["serial"] == "M0T08ECANE" }["kind"]).to eq "not_a_serial"
    end

    context "with stolen history on the serial under another manufacturer" do
      before { FactoryBot.create(:stolen_bike, serial_number: "WTU123456") }

      it "keeps the merge veto prominent" do
        get "#{base_url}/compare", params: {bike_ids: pair.map(&:id).join(",")}
        expect(response.code).to eq "200"
        expect(response.body).to include("Do not merge: this whole serial has stolen history")
      end
    end
  end

  describe "authenticated with an API token" do
    let(:current_user) { false } # No session - the token is the authentication
    include_context :admin_doorkeeper_token

    let(:url) { "#{base_url}.json" }
    include_examples "rejects_unauthorized_token"

    context "token for a duplicate_bikes superuser" do
      let(:email_pattern) { /[^@\s"]+@[^@\s"]+\.\w+/ }
      before do
        FactoryBot.create(:superuser_ability, user: token_user, controller_name: "duplicate_bikes")
        stub_const("ENV", ENV.to_h.merge("DUPLICATE_REVIEW_CONTACT_EMAILS" => "rider0@example.com, reviewer@partner.bikeindex.org"))
      end

      it "returns queues and groups without contact emails" do
        get url, params: token_param.merge(search_kind: "large_group")
        expect(response.status).to eq 200
        expect(json_result[:queues][:large_group]).to eq({label: "Large groups — validate the serial", groups: 1, records: 11}.as_json)
        group = json_result[:groups].first
        expect(group[:bike_ids]).to match_array marked_bikes.map(&:id)
        expect(group[:cues].map { it[:key] }).to include("standard_marking", "review_contact")
        expect(json_result[:total_count]).to eq 1
        expect(response.body).to_not match(email_pattern)
      end

      it "returns a comparison without contact emails" do
        get "#{base_url}/serial.json", params: token_param.merge(reference_bike_id: pair.last.id)
        expect(response.status).to eq 200
        expect(json_result[:records].map { it[:id] }).to eq pair.map(&:id)
        expect(json_result[:differing_fields].keys).to include("Model")
        expect(json_result[:contact_groups].first).to include(number: 1, email_present: true)
        expect(json_result[:serial_stolen]).to be false
        expect(json_result[:checks].first.keys).to eq %w[status label]
        expect(response.body).to_not match(email_pattern)
      end

      it "reports preparation while the cache is empty" do
        cache.delete(cache_key)
        get url, params: token_param
        expect(response.status).to eq 202
        expect(json_result[:status]).to eq "preparing"
      end
    end
  end
end
