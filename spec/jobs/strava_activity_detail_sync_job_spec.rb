require "rails_helper"

RSpec.describe StravaActivityDetailSyncJob, type: :job do
  let(:instance) { described_class.new }

  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe "perform" do
    let(:strava_integration) do
      FactoryBot.create(:strava_integration,
        token_expires_at: Time.current + 6.hours,
        athlete_id: ENV["STRAVA_TEST_USER_ID"],
        status: :syncing)
    end
    let(:activity) do
      FactoryBot.create(:strava_activity,
        strava_integration:,
        strava_id: "17323701543",
        activity_type: "EBikeRide")
    end

    it "fetches detail and updates the activity" do
      VCR.use_cassette("strava-get_activity") do
        instance.perform(activity.id)

        activity.reload
        expect(activity.description).to eq("Hawk with Eric and Scott and cedar")
        expect(activity.gear_name).to eq("Yuba longtail")
        expect(activity.kudos_count).to eq(17)
        expect(activity.photos).to be_present
        expect(activity.photos.first["id"]).to eq("8A14E2BB-A5E5-47E2-A36C-379B307E8AE7")
        expect(activity.segment_locations["cities"]).to include("San Francisco")
        expect(activity.segment_locations["states"]).to include("California")
      end
    end

    it "marks integration as synced when mark_synced is true" do
      VCR.use_cassette("strava-get_activity") do
        instance.perform(activity.id, true)

        expect(strava_integration.reload.status).to eq("synced")
      end
    end

    it "does not mark synced when mark_synced is false" do
      VCR.use_cassette("strava-get_activity") do
        instance.perform(activity.id, false)

        expect(strava_integration.reload.status).to eq("syncing")
      end
    end

    it "does nothing when activity not found" do
      instance.perform(-1)
    end
  end
end
