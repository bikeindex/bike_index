require "rails_helper"

RSpec.describe ParkingNotification, type: :model do
  it_behaves_like "geocodeable"

  describe "factory" do
    let(:parking_notification) { FactoryBot.create(:parking_notification, kind: "appears_abandoned_notification") }
    let(:bike) { parking_notification.bike }
    it "is valid" do
      expect(parking_notification.valid?).to be_truthy
      expect(parking_notification.id).to be_present
      expect(parking_notification.owner_known?).to be_truthy
      expect(parking_notification.send_email?).to be_truthy
      expect(bike.current_parking_notification).to eq parking_notification
      expect(bike.status_abandoned?).to be_truthy
      expect(bike.status).to eq "status_abandoned"
      expect(parking_notification.organization).to be_nil
    end
    context "organized record" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:bike) { FactoryBot.create(:bike, created_at: Time.current - 2.weeks) }
      let!(:parking_notification) { FactoryBot.create(:parking_notification_organized, organization: organization, bike: bike) }
      let!(:parking_notification2) { FactoryBot.create(:parking_notification, user: parking_notification.user) }
      let!(:parking_notification3) { FactoryBot.create(:parking_notification_organized) }
      it "is valid" do
        expect(parking_notification.valid?).to be_truthy
        expect(parking_notification.owner_known?).to be_truthy
        expect(parking_notification.send_email?).to be_truthy
        expect(bike.current_parking_notification).to eq parking_notification
        expect(parking_notification.retrieval_link_token).to be_present
        expect(parking_notification.organization).to eq organization
        expect(parking_notification.user.organizations).to eq([organization])
        expect(parking_notification2.organization_id).to be_blank
        expect(parking_notification3.organization_id).to_not eq organization.id
        expect(ParkingNotification.bikes.pluck(:id)).to match_array([bike.id, parking_notification2.bike_id, parking_notification3.bike_id])
        organization.reload
        expect(organization.parking_notifications.bikes.pluck(:id)).to eq([bike.id])
        expect(organization.auto_user).to be_blank
        expect(parking_notification.reply_to_email).to eq parking_notification.user.email
      end
    end
  end

  describe "reply_to_email" do
    let(:organization) { FactoryBot.create(:organization_with_auto_user) }
    let(:parking_notification) { FactoryBot.build(:parking_notification_organized, organization: organization) }
    it "organization auto_user, because it's present" do
      expect(parking_notification.should_be_geocoded?).to be_falsey
      expect(parking_notification.user).to_not eq organization.auto_user
      expect(parking_notification.reply_to_email).to eq organization.auto_user.email
    end
  end

  describe "unregistered" do
    let(:parking_notification) { FactoryBot.create(:unregistered_parking_notification) }
    let(:organization) { parking_notification.organization }
    let(:bike) { parking_notification.bike }
    it "is unregistered" do
      parking_notification.reload
      expect(parking_notification.bike.unregistered_parking_notification?).to be_truthy
      expect(parking_notification.bike.created_by_parking_notification).to be_truthy
      expect(parking_notification.unregistered_bike).to be_truthy
      expect(parking_notification.retrieval_link_token).to be_blank
      expect(parking_notification.bike.unregistered_parking_notification?).to be_truthy
      expect(organization.parking_notifications.bikes.pluck(:id)).to eq([bike.id])
    end
  end

  describe "initial/repeat_record" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: %w[parking_notifications impound_bikes]) }
    let(:parking_notification) { FactoryBot.build(:parking_notification, is_repeat: true, bike: bike, organization: organization, kind: "parked_incorrectly_notification") }
    it "repeat_record is false (also, test that abandoned updates bike status)" do
      bike.reload
      expect(bike.status).to eq "status_with_owner"
      expect(parking_notification.likely_repeat?).to be_falsey
      expect(parking_notification.can_be_repeat?).to be_falsey
      parking_notification.kind = "appears_abandoned_notification" # Manually set parking notification kind
      expect(parking_notification.associated_notifications).to eq([])
      expect(parking_notification.associated_notifications_including_self.pluck(:id)).to eq([]) # Since there is no id
      expect(parking_notification.save)
      expect(parking_notification.repeat_record?).to be_falsey
      expect(parking_notification.status).to eq "current"
      bike.reload
      expect(bike.status).to eq "status_abandoned"
    end
    context "existing" do
      let!(:parking_notification_initial) { FactoryBot.create(:parking_notification, bike: bike, organization: initial_organization, created_at: Time.current - 1.year) }
      let(:initial_organization) { FactoryBot.create(:organization) }
      it "repeat_record is false - and test that bike status isn't changed" do
        bike.reload
        expect(bike.status).to eq "status_with_owner"
        expect(parking_notification_initial.current?).to be_truthy
        expect(parking_notification_initial.initial_record?).to be_truthy
        expect(parking_notification.likely_repeat?).to be_falsey
        expect(parking_notification.can_be_repeat?).to be_falsey
        expect(parking_notification.save)
        expect(parking_notification.repeat_record?).to be_falsey
        parking_notification_initial.reload
        bike.reload
        expect(bike.status).to eq "status_with_owner"
      end
      context "same organization" do
        let(:initial_organization) { organization }
        let(:impound_record) { FactoryBot.create(:impound_record, organization: initial_organization, bike: bike) }
        it "can be assigned" do
          expect(parking_notification.potential_initial_record).to eq parking_notification_initial
          expect(parking_notification.likely_repeat?).to be_falsey
          expect(parking_notification.can_be_repeat?).to be_truthy
          expect(parking_notification.save)
          expect(parking_notification.repeat_record?).to be_truthy
          expect(parking_notification.initial_record).to eq parking_notification_initial
          expect(parking_notification_initial.repeat_records.pluck(:id)).to match_array([parking_notification.id])

          parking_notification_initial.update_attributes(impound_record: impound_record)
          parking_notification_initial.reload
          parking_notification.reload
          expect(parking_notification_initial.repeat_records.pluck(:id)).to match_array([parking_notification.id])
          expect(parking_notification.likely_repeat?).to be_falsey
          expect(parking_notification.can_be_repeat?).to be_truthy
          expect(parking_notification.potential_initial_record).to eq parking_notification_initial

          expect(parking_notification_initial.associated_notifications.pluck(:id)).to eq([parking_notification.id])
          expect(parking_notification.associated_notifications.pluck(:id)).to eq([parking_notification_initial.id])
          expect(parking_notification.associated_notifications_including_self.pluck(:id)).to match_array([parking_notification_initial.id, parking_notification.id])
        end
        context "additional parking_notification" do
          let!(:parking_notification2) { FactoryBot.create(:parking_notification, bike: bike, organization: initial_organization, created_at: Time.current - 1.week, initial_record: parking_notification_initial) }
          it "can be assigned" do
            expect(parking_notification.likely_repeat?).to be_truthy
            expect(parking_notification.can_be_repeat?).to be_truthy
            expect(parking_notification.save)
            expect(parking_notification.repeat_record?).to be_truthy
            expect(parking_notification.initial_record).to eq parking_notification_initial
            expect(parking_notification2.initial_record).to eq parking_notification_initial
            expect(parking_notification_initial.repeat_records.pluck(:id)).to match_array([parking_notification.id, parking_notification2.id])
            expect(parking_notification_initial.repeat_number).to eq 0
            expect(parking_notification2.repeat_number).to eq 1
            expect(parking_notification.repeat_number).to eq 2
          end
        end
      end
    end
  end

  describe "subject" do
    let(:bike) { FactoryBot.create(:bike, cycle_type: 'pedi-cab') }
    let(:parking_notification) { FactoryBot.create(:parking_notification_organized, kind: "parked_incorrectly_notification", bike: bike) }
    let(:organization) { parking_notification.organization }
    it "is default with snippet" do
      expect(parking_notification.mail_snippet).to be_blank
      expect(parking_notification.subject).to eq "Your pedi cab (rickshaw) is parked incorrectly"
    end
    context "with mail_snippet" do
      let!(:mail_snippet) do
        FactoryBot.create(:mail_snippet,
                          kind: "parked_incorrectly_notification",
                          subject: "Some crazy subject",
                          organization: organization,
                          is_enabled: true)
      end
      it "returns the mail_snippet" do
        expect(parking_notification.mail_snippet).to eq mail_snippet
        expect(parking_notification.subject).to eq "Some crazy subject"
      end
    end
  end

  describe "address" do
    # Copies StolenRecord, needs to be moved to a concern
    let(:country) { Country.create(name: "Neverland", iso: "NEVVVV") }
    let(:state) { State.create(country_id: country.id, name: "BullShit", abbreviation: "XXX") }
    it "creates an address" do
      parking_notification = ParkingNotification.new(street: "2200 N Milwaukee Ave",
                                                     city: "Chicago",
                                                     hide_address: true,
                                                     state_id: state.id,
                                                     zipcode: "60647",
                                                     country_id: country.id)
      expect(parking_notification.address).to eq("Chicago, XXX 60647, NEVVVV")
      expect(parking_notification.address(force_show_address: true)).to eq("2200 N Milwaukee Ave, Chicago, XXX 60647, NEVVVV")
      parking_notification.hide_address = false
      expect(parking_notification.address).to eq("2200 N Milwaukee Ave, Chicago, XXX 60647, NEVVVV")
    end
    it "is ok with missing information" do
      parking_notification = ParkingNotification.new(street: "2200 N Milwaukee Ave",
                                                     zipcode: "60647",
                                                     hide_address: true,
                                                     country_id: country.id)
      expect(parking_notification.address).to eq("60647, NEVVVV")
      parking_notification.hide_address = false
      expect(parking_notification.address).to eq("2200 N Milwaukee Ave, 60647, NEVVVV")
    end
    it "returns even if no country" do
      parking_notification = ParkingNotification.new(street: "302666 Richmond Blvd")
      expect(parking_notification.address).to eq parking_notification.street
    end
  end

  describe "set_calculated_attributes" do
    context "geolocated" do
      let(:ownership) { FactoryBot.create(:ownership, owner_email: "stuff@stuff.com") }
      let(:bike) { ownership.bike }
      let(:parking_notification) { FactoryBot.build(:parking_notification, bike: bike, latitude: nil, longitude: nil) }
      it "sets the email from the bike, fails without location" do
        expect(bike.owner_email).to eq "stuff@stuff.com"
        parking_notification.save
        expect(parking_notification.valid?).to be_falsey
        expect(parking_notification.errors.messages.to_s).to match(/address/)
        expect(parking_notification.kind_humanized).to eq "Parked incorrectly"
      end
    end
    context "no address" do
      let!(:state) { State.find_or_create_by(FactoryBot.attributes_for(:state_new_york)) }
      let!(:country) { Country.united_states }
      let(:parking_notification) { FactoryBot.build(:parking_notification, latitude: default_location[:latitude], longitude: default_location[:longitude]) }
      it "sets address" do
        parking_notification.save
        expect(parking_notification.state).to eq state
        expect(parking_notification.country).to eq country
        expect(parking_notification.address).to be_present
        expect(parking_notification.valid?).to be_truthy
        expect(parking_notification.id).to be_present
        expect(parking_notification.location_from_address).to be_falsey
      end
    end

    context "address set" do
      let(:latitude) { 41.9202384 }
      let(:longitude) { -87.7158185 }
      let(:parking_notification) { FactoryBot.build(:parking_notification, latitude: nil, longitude: nil, street: "3554 W Shakespeare Ave, 60647") }
      include_context :geocoder_real
      it "falls back to address" do
        VCR.use_cassette("parking_notification-address_lookup") do
          parking_notification.save
          expect(parking_notification.latitude).to eq latitude
          expect(parking_notification.longitude).to eq longitude
          expect(parking_notification.valid?).to be_truthy
          expect(parking_notification.id).to be_present
          expect(parking_notification.location_from_address).to be_truthy
        end
      end
      context "use_entered_address and lat/long set" do
        it "uses address" do
          VCR.use_cassette("parking_notification-address_lookup") do
            parking_notification.update_attributes(use_entered_address: true, latitude: 34.05223, longitude: -118.24368)
            expect(parking_notification.latitude).to eq latitude
            expect(parking_notification.longitude).to eq longitude
            expect(parking_notification.valid?).to be_truthy
            expect(parking_notification.id).to be_present
            expect(parking_notification.location_from_address).to be_truthy
          end
        end
      end
    end
  end

  describe "mark_retrieved!" do
    let(:parking_notification) { FactoryBot.create(:parking_notification) }
    let(:user) { parking_notification.user }
    it "marks retrieved and enqueues processing, but only once" do
      expect(parking_notification.active?).to be_truthy
      # test setting the attrs and the overrides (because local keyword args)
      parking_notification.resolved_at = Time.current - 2.hours
      parking_notification.retrieved_by_id = 12121212
      expect do
        parking_notification.mark_retrieved!(retrieved_by_id: user.id, retrieved_kind: "organization_recovery")
      end.to change(ProcessParkingNotificationWorker.jobs, :count).by 1
      parking_notification.reload
      expect(parking_notification.active?).to be_falsey
      expect(parking_notification.retrieved?).to be_truthy
      expect(parking_notification.retrieved_by).to eq user
      expect(parking_notification.resolved_at).to be_within(5).of Time.current
      expect(parking_notification.associated_retrieved_notification).to eq parking_notification
      expect do
        parking_notification.mark_retrieved!(retrieved_by_id: user.id, retrieved_kind: "organization_recovery")
      end.to_not change(ProcessParkingNotificationWorker.jobs, :count)
    end
    context "mark_retrieved without a user" do
      it "retrieves" do
        expect(parking_notification.active?).to be_truthy
        expect do
          parking_notification.mark_retrieved!(retrieved_kind: "link_token_recovery")
        end.to change(ProcessParkingNotificationWorker.jobs, :count).by 1
        parking_notification.reload
        expect(parking_notification.active?).to be_falsey
        expect(parking_notification.retrieved?).to be_truthy
        expect(parking_notification.retrieved_by).to be_blank
        expect(parking_notification.resolved_at).to be_within(5).of Time.current
        expect(parking_notification.associated_retrieved_notification).to eq parking_notification
      end
    end
  end

  describe "retrieve_or_repeat_notification!" do
    let(:parking_notification) { FactoryBot.create(:parking_notification) }
    let(:user) { FactoryBot.create(:user) }
    context "mark_retrieved" do
      it "retrieves" do
        og_token = parking_notification.retrieval_link_token
        expect(og_token).to be_present
        expect(parking_notification.current?).to be_truthy
        expect(parking_notification.retrieved?).to be_falsey
        expect do
          new_parking_notification = parking_notification.retrieve_or_repeat_notification!(user_id: user.id, kind: "mark_retrieved")
          expect(new_parking_notification.id).to eq parking_notification.id # Just checking
        end.to change(ProcessParkingNotificationWorker.jobs, :count).by 1
        parking_notification.reload
        expect(parking_notification.retrieved?).to be_truthy
        expect(parking_notification.resolved_at).to be_within(1.second).of Time.current
        expect(parking_notification.retrieved_kind).to eq "organization_recovery"
        expect(parking_notification.retrieved_by).to eq user
        expect(parking_notification.retrieval_link_token).to eq og_token # Why not leave it around
      end
      context "impounded" do
        let(:parking_notification) { FactoryBot.create(:parking_notification, kind: "impound_notification") }
        it "fails" do
          parking_notification.reload
          expect do
            new_parking_notification = parking_notification.retrieve_or_repeat_notification!(user_id: user.id, kind: "mark_retrieved")
            expect(new_parking_notification.id).to eq parking_notification.id # Just checking
          end.to_not change(ParkingNotification, :count)
        end
      end
    end
    context "another kind" do
      it "creates" do
        expect(parking_notification.kind).to eq "parked_incorrectly_notification"
        og_token = parking_notification.retrieval_link_token
        expect(og_token).to be_present
        expect(parking_notification.current?).to be_truthy
        expect(parking_notification.retrieved?).to be_falsey
        expect do
          parking_notification.retrieve_or_repeat_notification!(user_id: user.id, kind: "appears_abandoned_notification")
        end.to change(ProcessParkingNotificationWorker.jobs, :count).by 1

        new_parking_notification = ParkingNotification.last
        expect(new_parking_notification.bike).to eq parking_notification.bike
        expect(new_parking_notification.organization).to eq parking_notification.organization
        expect(new_parking_notification.initial_record).to eq parking_notification
        expect(new_parking_notification.kind).to eq "appears_abandoned_notification"
        expect(new_parking_notification.retrieved?).to be_falsey
        expect(new_parking_notification.current?).to be_truthy
      end
      context "already retrieved" do
        let(:resolved_at) { Time.current - 26.hours }
        let(:parking_notification) { FactoryBot.create(:parking_notification, :retrieved, resolved_at: resolved_at) }
        it "does not create" do
          parking_notification.reload
          expect(parking_notification.retrieved?).to be_truthy
          expect(parking_notification.resolved_at).to be_within(1).of resolved_at # Testing factory functionality
          expect do
            new_parking_notification = parking_notification.retrieve_or_repeat_notification!(user_id: user.id, kind: "mark_retrieved")
            expect(new_parking_notification.id).to eq parking_notification.id
          end.to_not change(ParkingNotification, :count)
        end
      end
    end
  end
end
