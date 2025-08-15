require "rails_helper"

RSpec.describe StolenRecord, type: :model do
  it_behaves_like "geocodeable"
  it_behaves_like "default_currencyable"

  describe "factories" do
    let(:stolen_record) { FactoryBot.create(:stolen_record) }
    it "is valid" do
      expect(stolen_record).to be_valid
      expect(stolen_record.reload.images_attached?).to be_falsey
    end
    context "with images attached" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, :with_images) }
      it "is valid" do
        expect(stolen_record).to be_valid
        expect(stolen_record.reload.images_attached?).to be_truthy
      end
    end
  end

  describe "after_save hooks" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:stolen_record) { FactoryBot.create(:stolen_record, bike: bike) }

    context "if bike no longer exists" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, bike: bike) }
      it "removes alert_image" do
        expect(stolen_record.alert_image).to be_present

        Sidekiq::Testing.inline! do
          stolen_record.update_attribute(:bike, nil)
        end

        stolen_record.reload
        expect(stolen_record.bike).to be_blank
        expect(stolen_record.images_attached?).to be_falsey
      end
    end

    context "if phone changes" do
      it "enqueues update without location_changed" do
        # ensure not memoizing anything
        stolen_record_instance = StolenRecord.find(stolen_record.id)
        Sidekiq::Job.clear_all
        stolen_record_instance.update(phone: "1112223333")
        expect(StolenBike::AfterStolenRecordSaveJob.jobs.map { |j| j["args"] }.last.flatten)
          .to eq([stolen_record_instance.id, false])
      end
    end

    context "location changes" do
      it "enqueues update with location_changed" do
        stolen_record_instance = StolenRecord.find(stolen_record.id)
        Sidekiq::Job.clear_all
        stolen_record_instance.update(city: "New city")
        expect(StolenBike::AfterStolenRecordSaveJob.jobs.map { |j| j["args"] }.last.flatten)
          .to eq([stolen_record_instance.id, true])
      end
    end

    context "if being marked as recovered" do
      let!(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, bike: bike) }
      it "removes alert_image" do
        stolen_record.reload
        expect(stolen_record.alert_image).to be_present
        expect(stolen_record.bike.status_stolen?).to be_truthy
        bike.reload
        expect(bike.current_stolen_record_id).to eq stolen_record.id
        expect(bike.occurred_at).to be_present

        Sidekiq::Testing.inline! do
          stolen_record.add_recovery_information
        end
        stolen_record.reload
        bike.reload

        expect(bike.status_stolen?).to be_falsey
        expect(bike.current_stolen_record_id).to be_blank
        expect(bike.occurred_at).to be_blank

        expect(stolen_record.recovered?).to be_truthy
        expect(stolen_record.bike.status_stolen?).to be_falsey
      end
    end

    context "if not being marked as recovered" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, bike: bike) }
      it "does not removes alert_image" do
        expect(stolen_record.alert_image).to be_present

        Sidekiq::Testing.inline! do
          stolen_record.run_callbacks(:commit)
        end

        expect(stolen_record.alert_image).to be_present
      end
    end
    describe "update_not_current_records" do
      it "marks all the records that are not current, not current" do
        bike = FactoryBot.create(:bike)
        Sidekiq::Testing.inline! do
          stolen_record1 = FactoryBot.create(:stolen_record, bike: bike)
          bike.reload
          expect(bike.current_stolen_record_id).to eq(stolen_record1.id)
          stolen_record2 = FactoryBot.create(:stolen_record, bike: bike)
          expect(stolen_record1.reload.current).to be_falsey
          expect(stolen_record2.reload.current).to be_truthy
          expect(bike.reload.current_stolen_record_id).to eq stolen_record2.id
        end
      end
    end
  end

  it "has some defaults" do
    stolen_record = StolenRecord.new
    expect(stolen_record.current).to be_truthy
    expect(stolen_record.display_checklist?).to be_falsey
    expect(stolen_record.theft_alert_missing_photo?).to be_falsey
  end

  describe "find_or_create_recovery_link_token" do
    let(:stolen_record) { StolenRecord.new }
    it "returns an existing recovery_link_token" do
      stolen_record.recovery_link_token = "blah"
      expect(stolen_record).to_not receive(:save)
      expect(stolen_record.find_or_create_recovery_link_token).to eq "blah"
    end

    it "creates a recovery_link_token and saves" do
      stolen_record = StolenRecord.new
      expect(stolen_record).to receive(:save)
      result = stolen_record.find_or_create_recovery_link_token
      expect(result).to eq stolen_record.recovery_link_token
    end
  end

  describe "scopes" do
    it "default scopes to current" do
      expect(StolenRecord.all.to_sql).to eq(StolenRecord.unscoped.where(current: true).to_sql)
    end
    it "scopes approveds" do
      expect(StolenRecord.approveds.to_sql).to eq(StolenRecord.unscoped.where(current: true).where(approved: true).to_sql)
    end
    it "scopes approveds_with_reports" do
      expect(StolenRecord.approveds_with_reports.to_sql).to eq(StolenRecord.unscoped.where(current: true).where(approved: true)
                                                              .where("police_report_number IS NOT NULL").where("police_report_department IS NOT NULL").to_sql)
    end

    it "scopes not_tsved" do
      expect(StolenRecord.not_tsved.to_sql).to eq(StolenRecord.unscoped.where(current: true).where("tsved_at IS NULL").to_sql)
    end
    it "scopes recovered" do
      expect(StolenRecord.recovered.to_sql).to eq(StolenRecord.unscoped.where(current: false).to_sql)
      expect(StolenRecord.recovered_ordered.to_sql).to eq(StolenRecord.unscoped.where(current: false).order("recovered_at desc").to_sql)
    end
    it "scopes displayable" do
      expect(StolenRecord.can_share_recovery.to_sql).to eq(StolenRecord.unscoped.where(current: false, can_share_recovery: true).order("recovered_at desc").to_sql)
    end
    it "scopes tsv_today" do
      stolen1 = FactoryBot.create(:stolen_record, current: true, tsved_at: Time.current)
      stolen2 = FactoryBot.create(:stolen_record, current: true, tsved_at: nil)

      expect(StolenRecord.tsv_today.pluck(:id)).to match_array([stolen1.id, stolen2.id])
    end
  end

  describe "#address" do
    let(:country) { Country.create(name: "Neverland", iso: "NEVVVV") }
    let(:state) { State.create(country_id: country.id, name: "BullShit", abbreviation: "XXX") }
    it "creates an address" do
      stolen_record = StolenRecord.new(street: "2200 N Milwaukee Ave",
        city: "Chicago",
        state_id: state.id,
        zipcode: "60647",
        country_id: country.id)
      expect(stolen_record.address).to eq("Chicago, XXX 60647, NEVVVV")
      expect(stolen_record.address(force_show_address: true)).to eq("2200 N Milwaukee Ave, Chicago, XXX 60647, NEVVVV")
      expect(stolen_record.address).to eq("Chicago, XXX 60647, NEVVVV")
      expect(stolen_record.display_checklist?).to be_truthy
    end
    it "is ok with missing information" do
      stolen_record = StolenRecord.new(street: "2200 N Milwaukee Ave",
        zipcode: "60647",
        country_id: country.id)
      expect(stolen_record.address).to eq("60647, NEVVVV")
      expect(stolen_record.without_location?).to be_falsey
      expect(stolen_record.address).to eq("60647, NEVVVV")
    end
    it "returns nil if there is no country" do
      stolen_record = StolenRecord.new(street: "302666 Richmond Blvd")
      expect(stolen_record.address).to be_nil
    end
  end

  describe "tsv_row" do
    it "returns the tsv row" do
      stolen_record = FactoryBot.create(:stolen_record)
      stolen_record.bike.update_attribute :description, "I like tabs because i'm an \\tass\T right\N"
      row = stolen_record.tsv_row
      expect(row.split("\t").count).to eq(10)
      expect(row.split("\n").count).to eq(1)
    end
  end

  describe "recovery display status" do
    it "is not elibible" do
      expect(StolenRecord.new.recovery_display_status).to eq "not_eligible"
    end
    context "stolen record is recovered, unable to share" do
      it "is not displayed" do
        stolen_record = FactoryBot.create(:stolen_record_recovered, can_share_recovery: false)
        expect(stolen_record.recovery_display_status).to eq "not_eligible"
        bike = stolen_record.bike
        expect(bike.reload.status).to eq "status_with_owner"
      end
    end
    context "stolen record is recovered, able to share" do
      it "is waiting on decision when user marks that we can share" do
        stolen_record = FactoryBot.create(:stolen_record_recovered, :with_bike_image, can_share_recovery: true)

        expect(stolen_record.bike.thumb_path).to be_present
        expect(stolen_record.can_share_recovery).to be_truthy
        expect(stolen_record.recovery_display_status).to eq "waiting_on_decision"
      end
    end
    context "stolen record is recovered, sharable but no bike photo" do
      it "is not displayed" do
        stolen_record = FactoryBot.create(:stolen_record_recovered,
          can_share_recovery: true)
        expect(stolen_record.recovery_display_status).to eq "displayable_no_photo"
      end
    end
    context "stolen_record is displayed" do
      it "is displayed" do
        recovery_display = FactoryBot.create(:recovery_display)
        stolen_record = FactoryBot.create(:stolen_record_recovered,
          can_share_recovery: true,
          recovery_display: recovery_display)

        expect(stolen_record.recovery_display_status).to eq "recovery_displayed"
        expect(StolenRecord.recovered.with_recovery_display.pluck(:id)).to eq([stolen_record.id])
        expect(StolenRecord.recovered.without_recovery_display.pluck(:id)).to eq([])
      end
    end
    context "stolen_record is not_displayed" do
      it "is not_displayed" do
        stolen_record = FactoryBot.create(:stolen_record_recovered,
          recovery_display_status: "not_displayed",
          can_share_recovery: true)
        expect(stolen_record.recovery_display_status).to eq "not_displayed"
        expect(StolenRecord.recovered.pluck(:id)).to eq([stolen_record.id])
        expect(StolenRecord.recovered.with_recovery_display.pluck(:id)).to eq([])
        expect(StolenRecord.recovered.without_recovery_display.pluck(:id)).to eq([stolen_record.id])
      end
    end
  end

  describe "set_calculated_attributes" do
    describe "set_phone" do
      let(:stolen_record) { StolenRecord.new(phone: "000/000/0000", secondary_phone: "+220000000000 extension: 000") }
      it "it should set_phone" do
        stolen_record.set_calculated_attributes
        expect(stolen_record.phone).to eq("0000000000")
        expect(stolen_record.secondary_phone).to eq("+22 0000000000 x000")
      end
    end

    describe "titleize_city" do
      it "it should titleize_city" do
        stolen_record = StolenRecord.new(city: "INDIANAPOLIS, IN USA")
        stolen_record.set_calculated_attributes
        expect(stolen_record.city).to eq("Indianapolis")
      end

      it "it shouldn't remove other things" do
        stolen_record = StolenRecord.new(city: "Georgian la")
        stolen_record.set_calculated_attributes
        expect(stolen_record.city).to eq("Georgian La")
      end
    end

    describe "set_date" do
      let(:date) { Date.strptime("07-22-0014", "%m-%d-%Y") }
      let(:stolen_record) { StolenRecord.new(date_stolen: date) }
      it "it should set the year to something not stupid" do
        stolen_record.set_calculated_attributes
        expect(stolen_record.date_stolen.to_date.to_s).to eq("2014-07-22")
      end
    end
  end

  describe "corrected_date_stolen" do
    let(:result) { StolenRecord.corrected_date_stolen(date) }
    context "year last century" do
      let(:date) { Date.strptime("07-22-1913", "%m-%d-%Y") }
      it "it sets the year to not last century" do
        expect(result.to_date.to_s).to eq("2013-07-22")
      end
    end
    context "date next year" do
      let(:date) { Time.current + 2.months }
      it "it sets the year to last year" do
        expect(result.to_date).to eq((date - 1.year).to_date)
      end
    end
    context "timestamp" do
      let(:date) { (Time.current - 1.hour).to_i }
      it "it sets the year to last year" do
        expect(result).to be_within(1).of(Time.current - 1.hour)
      end
    end
  end

  describe "update_tsved_at" do
    it "does not reset on save" do
      t = Time.current - 1.minute
      stolen_record = FactoryBot.create(:stolen_record, tsved_at: t)
      stolen_record.update(theft_description: "Something new description wise")
      stolen_record.reload
      expect(stolen_record.tsved_at.to_i).to eq(t.to_i)
    end
    it "resets from an update to police report" do
      t = Time.current - 1.minute
      stolen_record = FactoryBot.create(:stolen_record, tsved_at: t)
      stolen_record.update(police_report_number: "89dasf89dasf")
      stolen_record.reload
      expect(stolen_record.tsved_at).to be_nil
    end
    it "resets from an update to police report department" do
      t = Time.current - 1.minute
      stolen_record = FactoryBot.create(:stolen_record, tsved_at: t)
      stolen_record.update(police_report_department: "CPD")
      stolen_record.reload
      expect(stolen_record.tsved_at).to be_nil
    end
  end

  describe "calculated_recovery_display_status" do
    context "recovery is not eligible for display" do
      let(:stolen_record) { FactoryBot.create(:stolen_record_recovered, can_share_recovery: false) }
      it "returns not_eligible" do
        expect(stolen_record.calculated_recovery_display_status).to eq "not_eligible"
      end
    end
    context "recovery is eligible for display but has no photo" do
      it "returns displayable_no_photo" do
        stolen_record = FactoryBot.create(:stolen_record_recovered,
          can_share_recovery: true)
        expect(stolen_record.calculated_recovery_display_status).to eq "displayable_no_photo"
      end
    end
    context "recovery is eligible for display" do
      it "returns waiting_on_decision" do
        stolen_record = FactoryBot.create(:stolen_record_recovered,
          :with_bike_image,
          can_share_recovery: true)
        expect(stolen_record.calculated_recovery_display_status).to eq "waiting_on_decision"
      end
    end
    context "recovery is displayed" do
      it "returns displayed" do
        recovery_display = FactoryBot.create(:recovery_display)
        stolen_record = FactoryBot.create(:stolen_record_recovered,
          can_share_recovery: true,
          recovery_display: recovery_display)
        expect(stolen_record.calculated_recovery_display_status).to eq "recovery_displayed"
      end
    end
    context "recovery has been marked as not eligible for display" do
      it "returns not_displayed" do
        stolen_record = FactoryBot.create(:stolen_record_recovered,
          can_share_recovery: true,
          recovery_display_status: "not_displayed")
        expect(stolen_record.calculated_recovery_display_status).to eq "not_displayed"
      end
    end
  end

  describe "add_recovery_information" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    let(:stolen_record) { bike.current_stolen_record }
    let(:user_id) { nil }
    let(:recovery_info) do
      {
        request_type: "bike_recovery",
        user_id: 69,
        request_bike_id: bike.id,
        recovered_description: "Some reason",
        index_helped_recovery: "true",
        can_share_recovery: "false",
        recovering_user_id: user_id
      }
    end
    before do
      expect(bike.status_stolen?).to be_truthy
      bike.reload
      expect(bike.status).to eq "status_stolen"
      stolen_record.add_recovery_information(recovery_request.as_json)
      bike.reload
      stolen_record.reload

      expect(bike.status_stolen?).to be_falsey
      expect(bike.status).to eq "status_with_owner"
      expect(stolen_record.recovered?).to be_truthy
      expect(stolen_record.current).to be_falsey
      expect(bike.current_stolen_record).not_to be_present
      expect(stolen_record.index_helped_recovery).to be_truthy
      expect(stolen_record.can_share_recovery).to be_falsey
      expect(stolen_record.recovering_user_id).to eq user_id
      stolen_record.reload
    end
    context "no recovered_at, no user" do
      let(:recovery_request) { recovery_info.except(:can_share_recovery) }
      it "updates recovered bike" do
        expect(stolen_record.recovered_at).to be_within(1.second).of Time.current
        expect(stolen_record.recovering_user).to be_blank
        expect(stolen_record.recovering_user_owner?).to be_falsey
      end
    end
    context "owner is bike owner" do
      let(:recovery_request) { recovery_info }
      let(:ownership) { FactoryBot.create(:ownership_claimed, bike: bike) }
      let(:user_id) { ownership.user_id }
      it "updates recovered bike and assigns recovering_user" do
        expect(stolen_record.recovering_user).to eq ownership.user
        expect(stolen_record.recovered_at).to be_within(1.second).of Time.current
        expect(stolen_record.recovering_user_owner?).to be_truthy
        expect(stolen_record.pre_recovering_user?).to be_falsey
      end
    end
    context "recovered_at" do
      let(:user_id) { FactoryBot.create(:user).id }
      let(:time_str) { "2017-01-31T23:57:56" }
      let(:target_timestamp) { 1485907076 }
      let(:recovery_request) { recovery_info.merge(recovered_at: time_str, timezone: "Atlantic/Reykjavik") }
      it "updates recovered bike and assigns date" do
        expect(stolen_record.recovered_at.to_i).to be_within(1).of target_timestamp
        expect(stolen_record.recovering_user_owner?).to be_falsey
        expect(stolen_record.pre_recovering_user?).to be_truthy
      end
    end
  end

  describe "#add_recovery_information" do
    it "returns true" do
      stolen_record = FactoryBot.create(:stolen_record)
      allow(stolen_record.bike).to receive(:save).and_return(true)
      expect(stolen_record.add_recovery_information).to eq(true)
    end
  end

  describe "locking_description_description_select_options" do
    it "returns an array of arrays" do
      options = StolenRecord.locking_description_select_options

      expect(options).to be_an_instance_of(Array)
      expect(options).to all(be_an_instance_of(Array))
      options.each { |label, value| expect(label).to eq(value) }
    end

    it "localizes as needed" do
      I18n.with_locale(:nl) do
        options = StolenRecord.locking_description_select_options
        options.each do |label, value|
          expect(label).to be_an_instance_of(String)
          expect(label).to_not eq(value)
        end
      end
    end
  end

  describe "locking_defeat_description_select_options" do
    it "returns an array of arrays" do
      options = StolenRecord.locking_defeat_description_select_options

      expect(options).to be_an_instance_of(Array)
      expect(options).to all(be_an_instance_of(Array))
      options.each { |label, value| expect(label).to eq(value) }
    end

    it "localizes as needed" do
      I18n.with_locale(:nl) do
        options = StolenRecord.locking_description_select_options
        options.each do |label, value|
          expect(label).to be_an_instance_of(String)
          expect(label).to_not eq(value)
        end
      end
    end
  end

  describe "#address" do
    context "given include_all" do
      it "returns all available location components" do
        stolen_record = FactoryBot.create(:stolen_record, :in_nyc)
        expect(stolen_record.address).to eq("New York, NY 10007, US")
        expect(stolen_record.address(country: [:skip_default])).to eq("New York, NY 10007")
        stolen_record.street = ""
        expect(stolen_record.without_location?).to be_truthy

        ca = FactoryBot.create(:state_california)
        stolen_record = FactoryBot.create(:stolen_record, city: nil, state: ca, country: Country.united_states)
        expect(stolen_record.address).to eq("CA, US")
        expect(stolen_record.address(country: [:skip_default])).to eq("CA")
      end
    end

    context "given only a city" do
      it "returns nil" do
        stolen_record = FactoryBot.create(:stolen_record, city: "New Paltz", state: nil)
        expect(stolen_record.address).to eq("New Paltz")
      end
    end
  end

  describe "not_spam" do
    let!(:bike) { FactoryBot.create(:bike, :with_stolen_record, likely_spam: true) }
    let(:stolen_record) { bike.current_stolen_record }
    it "skips likely_spam" do
      expect(StolenRecord.current.pluck(:id)).to eq([stolen_record.id])
      expect(StolenRecord.not_spam.pluck(:id)).to eq([])
    end
  end

  describe "latitude_public" do
    let(:latitude) { -122.2824933 }
    let(:longitude) { 37.837112 }
    let(:stolen_record) { StolenRecord.new(latitude: latitude, longitude: longitude) }
    it "is rounded" do
      expect(stolen_record.latitude_public).to eq(-122.28)
      expect(stolen_record.longitude_public).to eq longitude.round(2)
    end
  end

  describe "bike_index_geocode with reverse geocoding" do
    let(:latitude) { -122.2824933 }
    let(:longitude) { 37.837112 }
    let(:stolen_record) do
      FactoryBot.build(:stolen_record, skip_geocoding: false, city: " ",
        latitude: latitude, longitude: longitude, street: "Special Broadway location")
    end
    let(:country) { Country.united_states }
    let!(:state) { State.find_or_create_by(FactoryBot.attributes_for(:state_new_york)) }
    let(:target_attributes) do
      {
        street: "Special Broadway location",
        city: "New York",
        zipcode: "10007",
        neighborhood: "Tribeca",
        state_id: state.id,
        latitude: latitude,
        longitude: longitude
      }
    end
    # Block the initial Geocoding lookup
    before { allow(stolen_record).to receive(:address_changed?) { false } }
    it "geocodes" do
      expect(Geocoder).to receive(:search).and_call_original
      stolen_record.save!
      expect(stolen_record.reload).to have_attributes target_attributes
    end
    context "with location attributes set" do
      let(:location_attributes) { {country_id: country.id, state_id: FactoryBot.create(:state).id, zipcode: "99999", city: "A City"} }
      before { stolen_record.attributes = location_attributes }
      it "does not call geocoder" do
        expect(Geocoder).to_not receive(:search)
        stolen_record.save!
        expect(stolen_record.reload).to have_attributes location_attributes
      end
      context "with canada (no state_id)" do
        let(:location_attributes) { {country_id: Country.canada.id, state_id: nil, zipcode: "99999", city: "A City"} }
        it "does not call geocoder" do
          expect(Geocoder).to_not receive(:search)
          stolen_record.save!
          expect(stolen_record.reload).to have_attributes location_attributes
        end
      end
    end
  end

  describe "promoted alert recovery notification" do
    context "if marked as recovered while a promoted alert is active" do
      it "sends an admin notification" do
        stolen_record = FactoryBot.create(:stolen_record, :in_chicago)
        theft_alert = FactoryBot.create(:theft_alert, stolen_record: stolen_record, status: :active)
        stolen_record.reload
        expect(stolen_record.theft_alert_missing_photo?).to be_truthy
        expect(theft_alert.missing_location?).to be_falsey
        og_updated_at = theft_alert.updated_at

        Sidekiq::Testing.inline! do
          expect { stolen_record.add_recovery_information }.to change { ActionMailer::Base.deliveries.length }.by(1)
        end
        theft_alert.reload
        expect(theft_alert.updated_at).to be > og_updated_at
      end
    end
  end
end
