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
      FactoryBot.create(:bike, :with_ownership, manufacturer:, serial_number: "WTU123456", owner_email: "pair@bikeindex.org", frame_model: "Other model",
        propulsion_type: "pedal-assist")]
  end
  let(:finder) { BikeDuplicatesServices::Finder }

  before { finder.store_group_snapshot }
  after { RedisPool.conn { it.del(finder::SNAPSHOT_KEY, finder::PREPARING_KEY) } }

  describe "dashboard" do
    it "prepares the groups in the background, once" do
      RedisPool.conn { it.del(finder::SNAPSHOT_KEY) }
      expect {
        get base_url
        get base_url
      }.to change(BikeJobs::PrepareDuplicateReviewJob.jobs, :count).by 1
      expect(response.code).to eq "200"
      expect(response).to render_template(:preparing)

      BikeJobs::PrepareDuplicateReviewJob.drain
      get base_url, params: {search_kind: "large_group"}
      expect(response).to render_template(:dashboard)
      expect(assigns(:groups).map { it["record_count"] }).to eq [11]
    end

    it "serves an hour-old snapshot while a fresh one is prepared" do
      snapshot = JSON.parse(RedisPool.conn { it.get(finder::SNAPSHOT_KEY) })
      RedisPool.conn { it.set(finder::SNAPSHOT_KEY, snapshot.merge("generated_at" => 61.minutes.ago.to_i).to_json) }
      expect { get base_url, params: {search_kind: "large_group"} }.to change(BikeJobs::PrepareDuplicateReviewJob.jobs, :count).by 1
      expect(response).to render_template(:dashboard)
      expect(assigns(:groups).map { it["record_count"] }).to eq [11]
    end

    it "tries again on the next visit when the job can't be enqueued" do
      RedisPool.conn { it.del(finder::SNAPSHOT_KEY) }
      allow(BikeJobs::PrepareDuplicateReviewJob).to receive(:perform_async).and_raise(RedisClient::CannotConnectError)
      expect { finder.fetch_group_snapshot }.to raise_error(RedisClient::CannotConnectError)
      expect(RedisPool.conn { it.get(finder::PREPARING_KEY) }).to be_nil
    end

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
      12.times do |index|
        FactoryBot.create(:bike, :with_ownership, manufacturer:, serial_number: "0LDGR0UP1", owner_email: "older#{index}@bikeindex.org",
          created_at: Time.current - 2.years + index.days)
      end
      finder.store_group_snapshot

      get base_url, params: {search_kind: "large_group"}
      expect(assigns(:groups).map { it["record_count"] }).to eq [12, 11]

      get base_url, params: {search_kind: "large_group", sort: "first_at", direction: "asc"}
      expect(assigns(:groups).map { it["record_count"] }).to eq [12, 11]
      get base_url, params: {search_kind: "large_group", sort: "last_at"}
      expect(assigns(:groups).map { it["record_count"] }).to eq [11, 12]
      expect(response.body).to include("Latest registration")
    end

    it "keeps a crafted host or protocol out of its links" do
      get base_url, params: {search_kind: "large_group", host: "evil.example", protocol: "javascript"}
      expect(response.body).to include("search_kind=large_group")
      expect(response.body).to_not include("evil.example")
      expect(response.body).to_not include("javascript://")
    end

    it "rechecks the listed groups' stolen veto live" do
      FactoryBot.create(:stolen_bike, serial_number: "EN 14764")
      get base_url, params: {search_kind: "large_group"}
      expect(assigns(:groups).map { it["serial_stolen"] }).to eq [true]
      expect(response.body).to include("Stolen history — do not merge")
    end

    it "puts a strictly qualified shop-to-customer handoff in its priority queue" do
      user = FactoryBot.create(:user_confirmed)
      shop_bike = FactoryBot.create(:bike_lightspeed_pos, manufacturer:, serial_number: "HAND0FF123", owner_email: user.email, created_at: 2.days.ago)
      FactoryBot.create(:bike, :with_ownership_claimed, user:, manufacturer:, serial_number: "HAND0FF123")
      expect(finder.groups.find { it["bike_ids"].include?(shop_bike.id) }["kind"]).to eq "handoff_priority"
    end
  end

  describe "show" do
    it "reviews every record in a serial-segment group, hidden ones included, and offers to ignore it" do
      duplicate_group = DuplicateBikeGroup.create
      pair.each { NormalizedSerialSegment.create(bike: it, duplicate_bike_group: duplicate_group, segment: "WTU123456") }
      pair.last.update_column(:user_hidden, true)
      get "#{base_url}/#{duplicate_group.id}"
      expect(response.code).to eq "200"
      expect(assigns(:bikes_count)).to eq 2
      expect(response.body).to include("Ignore group", ignore_duplicate_toggle_admin_bikes_path(id: duplicate_group.id))
    end

    it "sends a group too large to review back to the segments list" do
      stub_const("Admin::DuplicateBikesController::MAX_REVIEW_RECORDS", 1)
      duplicate_group = DuplicateBikeGroup.create
      pair.each { NormalizedSerialSegment.create(bike: it, duplicate_bike_group: duplicate_group, segment: "WTU123456") }
      get "#{base_url}/#{duplicate_group.id}"
      expect(response).to redirect_to(admin_duplicate_bikes_path(search_view: "segments"))
      expect(flash[:error]).to eq "2 records are too many to review together"
    end

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
      expect(assigns(:review).differing_fields).to include("Model", "Propulsion")
      expect(response.body).to include("Initial vs reference", "Differs", "Shop default? Confirm propulsion with the owner")
      expect(response.body).to_not include("Do not merge")
    end

    it "notes a shop propulsion default without changing a passing pair's readiness" do
      user = FactoryBot.create(:user_confirmed)
      shop_bike = FactoryBot.create(:bike_lightspeed_pos, manufacturer:, serial_number: "EB1KE0123", owner_email: user.email,
        propulsion_type: "foot-pedal", created_at: 2.days.ago)
      customer_bike = FactoryBot.create(:bike, :with_ownership_claimed, user:, manufacturer:, serial_number: "EB1KE0123",
        propulsion_type: "pedal-assist")
      get "#{base_url}/compare", params: {bike_ids: [shop_bike.id, customer_bike.id].join(",")}
      expect(response.code).to eq "200"
      expect(response.body).to include("Shop default? Confirm propulsion with the owner", "Meets the strict same-owner evidence")
    end

    it "flags a part-number serial as not a duplicate match" do
      part_numbers = Array.new(2) { FactoryBot.create(:bike, :with_ownership, manufacturer:, serial_number: "SM-BBR60") }
      get "#{base_url}/compare", params: {bike_ids: part_numbers.map(&:id).join(",")}
      expect(response.code).to eq "200"
      expect(response.body).to include("Not a duplicate match: this serial is a part number (Shimano SM-BBR60 bottom bracket)", "Not a candidate")
    end

    it "treats a manufacturer name typed as the serial as a placeholder" do
      brand = FactoryBot.create(:manufacturer, name: "Motobecane")
      placeholders = Array.new(2) { FactoryBot.create(:bike, :with_ownership, manufacturer: brand, serial_number: "MOTOBECANE") }
      get "#{base_url}/compare", params: {bike_ids: placeholders.map(&:id).join(",")}
      expect(response.body).to include("this serial is a placeholder (manufacturer name Motobecane)")
      expect(finder.groups.find { it["serial"] == "M0T08ECANE" }["kind"]).to eq "not_a_serial"
    end

    it "vetoes a record's own stolen history when its serial is blank" do
      bikes = [FactoryBot.create(:stolen_bike, :with_ownership, manufacturer:, serial_number: "unknown"),
        FactoryBot.create(:bike, :with_ownership, manufacturer:, serial_number: "unknown")]
      get "#{base_url}/compare", params: {bike_ids: bikes.map(&:id).join(",")}
      expect(response.code).to eq "200"
      expect(assigns(:review).serial_stolen?).to be false
      expect(response.body).to include("Not a candidate", "A record has its own stolen history")
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
end
