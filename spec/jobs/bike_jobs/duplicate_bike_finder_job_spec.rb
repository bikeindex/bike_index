require "rails_helper"

RSpec.describe BikeJobs::DuplicateBikeFinderJob, type: :job do
  let(:instance) { described_class.new }

  it "takes a bike id and search for groups, ignoring any less than 5 chars" do
    bike1 = FactoryBot.create(:bike, serial_number: "applejacks cereal cross")
    bike1.create_normalized_serial_segments
    bike2 = FactoryBot.create(:bike, serial_number: "applejacks Funtimes cross")
    bike2.create_normalized_serial_segments
    expect {
      instance.perform(bike1.id)
    }.to change(DuplicateBikeGroup, :count).by 1

    expect {
      duplicate_group = bike1.normalized_serial_segments.first.duplicate_bike_group
      expect(bike2.normalized_serial_segments.first.duplicate_bike_group).to eq(duplicate_group)
    }.to_not change(DuplicateBikeGroup, :count)
  end

  context "not current bikes" do
    let!(:bike1) { FactoryBot.create(:bike, serial_number: "Y0AAS-FFFFF") }
    before do
      bike1.create_normalized_serial_segments
      bike2.create_normalized_serial_segments
    end
    context "user_hidden" do
      let!(:bike2) { FactoryBot.create(:bike, serial_number: "Y0AASFFFFF", user_hidden: true) }
      it "creates for user_hidden" do
        expect(DuplicateBikeGroup.count).to eq 0
        instance.perform(bike2.id)
        expect(bike2.reload.normalized_serial_segments.first.duplicate_bike_group).to be_present
        expect(bike2.duplicate_bikes.pluck(:id)).to eq([bike1.id])
        expect(DuplicateBikeGroup.count).to eq 1
      end
    end
    context "example" do
      let!(:bike2) { FactoryBot.create(:bike, serial_number: "Y0AASFFFFF", example: true) }
      it "doesn't create" do
        expect(DuplicateBikeGroup.count).to eq 0
        instance.perform(bike2.id)
        expect(bike2.reload.normalized_serial_segments.count).to eq 0
        expect(DuplicateBikeGroup.count).to eq 0
      end
    end
    context "likely_spam" do
      let!(:bike2) { FactoryBot.create(:bike, serial_number: "Y0AASFFFFF", likely_spam: true) }
      it "doesn't create" do
        expect(DuplicateBikeGroup.count).to eq 0
        instance.perform(bike2.id)
        expect(bike2.reload.normalized_serial_segments.count).to eq 0
        expect(DuplicateBikeGroup.count).to eq 0
      end
    end
    context "deletion" do
      let!(:bike2) { FactoryBot.create(:bike, serial_number: "Y0A ASF FFFF") }
      it "deletes segments on deletion" do
        expect(BikeJobs::DuplicateBikeFinderJob.jobs.count).to eq 0 # TODO: remove after tests pass
        expect(DuplicateBikeGroup.count).to eq 0
        instance.perform(bike2.id)
        expect(bike2.reload.normalized_serial_segments.count).to eq 4
        expect(bike2.duplicate_bikes.pluck(:id)).to eq([bike1.id])
        expect(DuplicateBikeGroup.count).to eq 1
        bike2.destroy
        # Bike destroy enqueues the duplicate bike finder
        expect(BikeJobs::DuplicateBikeFinderJob.jobs.count).to eq 1
        BikeJobs::DuplicateBikeFinderJob.drain
        expect(bike2.reload.normalized_serial_segments.count).to eq 0
        expect(DuplicateBikeGroup.count).to eq 0
      end
    end
  end

  context "only one match" do
    it "doesn't create a duplicate" do
      bike = FactoryBot.create(:bike, serial_number: "applejacks")
      bike.create_normalized_serial_segments
      expect(DuplicateBikeGroup.count).to eq 0
      instance.perform(bike.id)
      expect(bike.normalized_serial_segments.first.duplicate_bike_group).to_not be_present
      expect(DuplicateBikeGroup.count).to eq 0
    end
  end

  context "existing duplicate bike group" do
    it "adds a bike to an existing duplicate bike group" do
      bike1 = FactoryBot.create(:bike, serial_number: "applejacks")
      bike1.create_normalized_serial_segments
      bike2 = FactoryBot.create(:bike, serial_number: "applejacks")
      bike2.create_normalized_serial_segments
      t = Time.at(1441314105)
      duplicate_group = DuplicateBikeGroup.create(added_bike_at: t)
      expect(duplicate_group.added_bike_at).to eq(t)
      bike1.normalized_serial_segments.first.update_attribute :duplicate_bike_group_id, duplicate_group.id
      bike2.normalized_serial_segments.first.update_attribute :duplicate_bike_group_id, duplicate_group.id
      bike3 = FactoryBot.create(:bike, serial_number: "applejacks")
      bike3.create_normalized_serial_segments
      instance.perform(bike3.id)
      expect(bike3.normalized_serial_segments.first.duplicate_bike_group).to eq(duplicate_group)
      duplicate_group.reload
      expect(duplicate_group.added_bike_at).to_not eq(t)
    end
  end

  describe "stolen serial marketplace match" do
    let(:listed_bike) { FactoryBot.create(:bike, :with_primary_activity, :with_ownership_claimed, serial_number: "WTU171G0123C") }
    let(:stolen_bike) { FactoryBot.create(:stolen_bike, serial_number: "WTU171G0123C") }
    let(:status) { :for_sale }
    let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, item: listed_bike, status:) }
    let(:bike_id) { listed_bike.id }
    let(:target_attributes) do
      {kind: "stolen_serial_marketplace_match", bike_id: listed_bike.id, notifiable: stolen_bike, user_id: nil,
       delivery_status: "delivery_success", message_channel_target: "bryan@bikeindex.org, gavin@bikeindex.org"}
    end
    before do
      [listed_bike, stolen_bike].each(&:create_normalized_serial_segments)
      Sidekiq::Job.clear_all
      ActionMailer::Base.deliveries.clear
    end

    def run_job(id)
      described_class.perform_async(id)
      described_class.drain
    end

    it "emails admins once, however many times it runs for either bike" do
      expect(marketplace_listing.reload.status).to eq "for_sale"
      expect(stolen_bike.status).to eq "status_stolen"
      expect { run_job(bike_id) }.to change(Notification, :count).by 1
      expect(Notification.last).to have_attributes(target_attributes)
      expect(ActionMailer::Base.deliveries.count).to eq 1
      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(%w[bryan@bikeindex.org gavin@bikeindex.org])
      expect(mail.body.encoded).to include("/admin/marketplace_listings/#{marketplace_listing.id}")

      expect {
        run_job(listed_bike.id)
        run_job(stolen_bike.id)
      }.to_not change(Notification, :count)
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end

    context "run for the stolen bike" do
      let(:bike_id) { stolen_bike.id }
      it "emails admins with the listed bike as the bike" do
        expect { run_job(bike_id) }.to change(Notification, :count).by 1
        expect(Notification.last).to have_attributes(target_attributes)
        expect(ActionMailer::Base.deliveries.count).to eq 1
      end
    end

    context "in an ignored group" do
      before do
        duplicate_bike_group = DuplicateBikeGroup.create(ignore: true)
        NormalizedSerialSegment.update_all(duplicate_bike_group_id: duplicate_bike_group.id)
      end
      it "doesn't email" do
        expect {
          run_job(listed_bike.id)
          run_job(stolen_bike.id)
        }.to_not change(Notification, :count)
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end

    context "listing not for sale" do
      let(:status) { :draft }
      it "doesn't email" do
        expect {
          run_job(listed_bike.id)
          run_job(stolen_bike.id)
        }.to_not change(Notification, :count)
        expect(stolen_bike.reload.duplicate_bikes.pluck(:id)).to eq([listed_bike.id])
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end
  end

  context "bike gone" do
    it "doesn't explode" do
      expect {
        instance.perform(12121212)
      }.to_not raise_error
    end
  end
end
