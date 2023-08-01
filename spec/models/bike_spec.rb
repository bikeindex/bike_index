require "rails_helper"

RSpec.describe Bike, type: :model do
  it_behaves_like "bike_searchable"
  it_behaves_like "geocodeable"
  it_behaves_like "bike_attributable"

  describe "scopes and searching" do
    describe "scopes" do
      it "default scopes to created_at desc" do
        expect(Bike.all.to_sql).to eq(Bike.unscoped.where(example: false, user_hidden: false, deleted_at: nil).order(listing_order: :desc).to_sql)
      end
      it "recovered_records default scopes to created_at desc" do
        bike = FactoryBot.create(:bike)
        expect(bike.recovered_records.to_sql).to eq(StolenRecord.unscoped.where(bike_id: bike.id, current: false).order("recovered_at desc").to_sql)
      end
    end

    describe "friendly_find" do
      let(:id) { 1999999 }
      let!(:bike) { FactoryBot.create(:bike, id: id) }
      it "finds" do
        expect(Bike.friendly_find(id)&.id).to eq bike.id
        expect(Bike.friendly_find("  #{id}\n")&.id).to eq bike.id
        expect(Bike.friendly_find("https://bikeindex.org/bikes/#{id}")&.id).to eq bike.id
        expect(Bike.friendly_find("bikeindex.org/bikes/#{id}/edit?edit_template=accessories")&.id).to eq bike.id
        # Check range error - currently IDs are integer with limit of 4 bytes
        expect(Bike.friendly_find("2147483648")&.id).to eq nil
        expect(Bike.friendly_find(" 9999999999999")&.id).to eq nil
      end
    end

    describe ".currently_stolen_in" do
      context "given no matching state or country" do
        it "returns none" do
          FactoryBot.create(:stolen_bike_in_nyc)
          FactoryBot.create(:stolen_bike_in_los_angeles)
          expect(Bike.currently_stolen_in(country: "New York City")).to be_empty
          expect(Bike.currently_stolen_in(state: "New York City", country: "Svenborgia")).to be_empty
          expect(Bike.currently_stolen_in(city: "Los Angeles", country: "NL")).to be_empty
        end
      end

      context "given no matching stolen bikes in a valid state or country" do
        it "returns none" do
          expect(StolenRecord.count).to eq(0)
          expect(Bike.currently_stolen_in(country: "US")).to be_empty
        end
      end

      context "given a currently stolen bike in a matching city or state" do
        it "returns only the requested bikes" do
          FactoryBot.create(:stolen_bike_in_amsterdam)
          FactoryBot.create(:stolen_bike_in_los_angeles)
          FactoryBot.create(:stolen_bike_in_nyc)

          bikes = Bike.currently_stolen_in(city: "Los Angeles")
          expect(bikes.map(&:current_stolen_record).map(&:city)).to match_array(["Los Angeles"])

          bikes = Bike.currently_stolen_in(state: "NY", country: "US")
          expect(bikes.map(&:current_stolen_record).map(&:city)).to match_array(["New York"])

          bikes = Bike.currently_stolen_in(state: "NY", country: "NL")
          expect(bikes).to be_empty
        end
      end

      context "given currently stolen bikes in a matching country" do
        it "returns only the requested bikes" do
          FactoryBot.create(:stolen_bike_in_amsterdam)
          FactoryBot.create(:stolen_bike_in_los_angeles)
          FactoryBot.create(:stolen_bike_in_nyc)

          bikes = Bike.currently_stolen_in(country: "NL")
          expect(bikes.map(&:current_stolen_record).map(&:city)).to match_array(["Amsterdam"])

          bikes = Bike.currently_stolen_in(country: "US")
          expect(bikes.map(&:current_stolen_record).map(&:city)).to match_array(["New York", "Los Angeles"])
        end
      end
    end

    describe "search_phone" do
      let(:stolen_record1) { FactoryBot.create(:stolen_record, phone: "2223334444") }
      let(:bike1) { stolen_record1.bike }
      let!(:stolen_record2) { FactoryBot.create(:stolen_record, phone: "111222333", bike: bike1) }
      let!(:stolen_record3) { FactoryBot.create(:stolen_record, phone: "2223334444", secondary_phone: "111222333") }
      let(:bike2) { stolen_record3.bike }
      it "finds by stolen_record" do
        AfterStolenRecordSaveWorker.new.perform(stolen_record2.id)
        expect(stolen_record1.reload.current?).to be_falsey
        stolen_record1.update_column :current, true
        bike1.reload
        expect(bike1.stolen_records.pluck(:id)).to match_array([stolen_record1.id, stolen_record2.id])
        # Ideally this would keep the scope, but it doesn't. So document that behavior here
        expect(Bike.where(id: [bike2.id]).search_phone("2223334444").pluck(:id)).to eq([bike1.id, bike2.id])
        expect(Bike.search_phone("2223334444").pluck(:id)).to match_array([bike1.id, bike2.id])
        expect(Bike.search_phone("23334444").pluck(:id)).to match_array([bike1.id, bike2.id])
        expect(Bike.search_phone("233344").pluck(:id)).to match_array([bike1.id, bike2.id])
        expect(Bike.search_phone("11222333").pluck(:id)).to match_array([bike1.id, bike2.id])
      end
    end

    describe "pg search" do
      it "returns a bike which has a matching part of its description" do
        bike = FactoryBot.create(:bike, description: "Phil wood hub")
        FactoryBot.create(:bike)
        expect(Bike.text_search("phil wood hub").pluck(:id)).to eq([bike.id])
      end
    end

    describe "organized_email_and_name_search" do
      let!(:bike1) { FactoryBot.create(:bike, owner_email: "something@stuff.edu") }
      let(:user) { FactoryBot.create(:user_confirmed, name: "George Jones", email: "something2@stuff.edu") }
      let!(:bike2) { FactoryBot.create(:bike, :with_ownership_claimed, owner_email: user.email, user: user) }
      let!(:bike3) { FactoryBot.create(:bike, :with_ownership, creation_registration_info: {user_name: "Sally Jones"}, owner_email: "something@stuff.com") }
      it "finds the things" do
        expect(bike2.reload.owner_name).to eq "George Jones"
        expect(bike3.reload.owner_name).to eq "Sally Jones"
        expect(Bike.organized_email_and_name_search("something").pluck(:id)).to match_array([bike1.id, bike2.id, bike3.id])
        expect(Bike.organized_email_and_name_search(" stuff ").pluck(:id)).to match_array([bike1.id, bike2.id, bike3.id])
        expect(Bike.organized_email_and_name_search("\nstuff.EDU  ").pluck(:id)).to match_array([bike1.id, bike2.id])
        expect(Bike.organized_email_and_name_search("jones").pluck(:id)).to match_array([bike2.id, bike3.id])
        expect(Bike.organized_email_and_name_search("  sally").pluck(:id)).to match_array([bike3.id])
        expect(Bike.claimed.pluck(:id)).to eq([bike2.id])
      end
    end

    describe ".possibly_found_with_match" do
      let(:bike1) { FactoryBot.create(:impounded_bike, serial_number: "He10o") }
      let(:bike1b) { FactoryBot.create(:impounded_bike, serial_number: "He10o") }
      let(:bike2) { FactoryBot.create(:stolen_bike, serial_number: "he110") }
      let(:bike2b) { FactoryBot.create(:impounded_bike, serial_number: "HEllO") }
      let(:bike3) { FactoryBot.create(:stolen_bike, serial_number: "1100ll") }
      let(:bike3b) { FactoryBot.create(:impounded_bike, serial_number: "IIOO11") }
      it "returns stolen bikes with a matching normalized serial on another abandoned bike" do
        pair0 = [bike1, bike1b]
        expect(bike1.reload.status).to eq "status_impounded"
        expect(bike1b.reload.status).to eq "status_impounded"

        pair1 = [bike2, bike2b]
        expect(bike2.reload.status).to eq "status_stolen"
        expect(bike2b.reload.status).to eq "status_impounded"

        pair2 = [bike3, bike3b]

        results = Bike.possibly_found_with_match
        expect(results.length).to eq(2)

        result_ids = results.map { |pair| pair.map(&:id) }
        expect(result_ids).to_not include(pair0.map(&:id))
        expect(result_ids).to match_array([pair1.map(&:id), pair2.map(&:id)])
      end
    end

    describe ".possibly_found_externally_with_match" do
      it "returns stolen bikes with a matching normalized serial on an external-registry bike" do
        pair0 = [
          FactoryBot.create(:stolen_bike, serial_number: "He10o"),
          FactoryBot.create(:external_registry_bike, serial_number: "He10o")
        ]

        pair1 = [
          FactoryBot.create(:stolen_bike_in_amsterdam, serial_number: "he110"),
          FactoryBot.create(:external_registry_bike, serial_number: "He1lo")
        ]

        pair2 = [
          FactoryBot.create(:stolen_bike_in_amsterdam, serial_number: "1100ll"),
          FactoryBot.create(:external_registry_bike, serial_number: "IIOO11")
        ]

        results = Bike.possibly_found_externally_with_match(country_iso: "NL")
        expect(results.length).to eq(2)

        result_ids = results.map { |pair| pair.map(&:id) }
        expect(result_ids).to_not include(pair0.map(&:id))
        expect(result_ids).to match_array([pair1.map(&:id), pair2.map(&:id)])
      end
    end
  end

  describe "factories and creation" do
    describe "build_new_stolen_record" do
      let(:bike) { FactoryBot.create(:bike_organized) }
      let(:organization) { bike.creation_organization }
      let(:us_id) { Country.united_states.id }
      it "builds a new record" do
        stolen_record = bike.build_new_stolen_record
        expect(stolen_record.country_id).to eq us_id
        expect(stolen_record.phone).to be_blank
        expect(stolen_record.date_stolen).to be > Time.current - 1.second
        expect(stolen_record.creation_organization_id).to eq organization.id
      end
      context "older record" do
        let(:country) { FactoryBot.create(:country) }
        it "builds new record without creation_organization" do
          bike.update(created_at: Time.current - 2.days)
          allow(bike).to receive(:phone) { "1112223333" }
          # Accepts properties
          stolen_record = bike.build_new_stolen_record(country_id: country.id)
          expect(stolen_record.country_id).to eq country.id
          expect(stolen_record.phone).to eq "1112223333"
          expect(stolen_record.date_stolen).to be > Time.current - 1.second
          expect(stolen_record.creation_organization_id).to be_blank
        end
      end
    end

    describe "build_new_impound_record" do
      let(:bike) { FactoryBot.create(:bike) }
      let(:us_id) { Country.united_states.id }
      it "builds a new record" do
        impound_record = bike.build_new_impound_record
        expect(impound_record.country_id).to eq us_id
        expect(impound_record.impounded_at).to be > Time.current - 1.second
        expect(impound_record.organization_id).to be_blank
      end
      context "organized record" do
        let(:bike) { FactoryBot.create(:bike_organized) }
        let(:organization) { bike.creation_organization }
        let(:country) { FactoryBot.create(:country) }
        it "builds new record without organization" do
          bike.update(created_at: Time.current - 2.days)
          # Accepts properties
          impound_record = bike.build_new_impound_record(country_id: country.id)
          expect(impound_record.country_id).to eq country.id
          expect(impound_record.impounded_at).to be > Time.current - 1.second
          expect(impound_record.organization_id).to be_blank
        end
      end
    end

    context "unknown, absent serials" do
      let(:bike_with_serial) { FactoryBot.create(:bike, serial_number: "CCcc99FFF") }
      let(:bike_made_without_serial) { FactoryBot.create(:bike, made_without_serial: true) }
      let(:bike_with_unknown_serial) { FactoryBot.create(:bike, serial_number: "????  \n") }
      it "corrects poorly entered serial numbers" do
        [bike_with_serial, bike_made_without_serial, bike_with_unknown_serial].each { |b| b.reload }
        expect(bike_with_serial.made_without_serial?).to be_falsey
        expect(bike_with_serial.serial_unknown?).to be_falsey
        expect(bike_made_without_serial.serial_number).to eq "made_without_serial"
        expect(bike_made_without_serial.made_without_serial?).to be_truthy
        expect(bike_made_without_serial.serial_unknown?).to be_falsey
        expect(bike_with_unknown_serial.made_without_serial?).to be_falsey
        expect(bike_with_unknown_serial.serial_unknown?).to be_truthy
        expect(bike_with_serial.serial_number).to eq "CCcc99FFF"
        expect(bike_made_without_serial.serial_number).to eq "made_without_serial"
        expect(bike_with_unknown_serial.serial_number).to eq "unknown"
        expect(Bike.with_known_serial.pluck(:id)).to match_array([bike_with_serial.id, bike_made_without_serial.id])
      end
    end

    describe "#normalize_serial_number" do
      let(:bike) { Bike.new(serial_number: serial_number) }
      before { bike.normalize_serial_number }

      context "given a bike made with no serial number" do
        no_serials = [
          "custom bike no serial has a unique frame design",
          "custom built",
          "custom"
        ]
        no_serials.each do |value|
          let(:serial_number) { value }
          it "('#{value}') sets the 'made_without_serial' state correctly" do
            expect(bike.serial_number).to eq("made_without_serial")
            expect(bike.made_without_serial).to eq(true)
            expect(bike.serial_normalized).to eq(nil)
          end
        end
      end

      context "given a bike with an unknown serial number" do
        unknown_serials = [
          " UNKNOWn ",
          "I don't know it",
          "I don't remember",
          "Sadly I don't know",
          "absent",
          "don't know",
          "i don't know",
          "idk",
          "missing serial",
          "missing",
          "no serial",
          "none",
          "probably has one don't know it",
          "unknown"
        ]
        unknown_serials.each do |value|
          let(:serial_number) { value }
          it "('#{value}') sets the 'unknown' state correctly" do
            expect(bike.serial_number).to eq("unknown")
            expect(bike.made_without_serial).to eq(false)
            expect(bike.serial_normalized).to eq(nil)
            expect(bike.serial_normalized_no_space).to eq(nil)
          end
        end
      end

      context "unknown" do
        let(:serial_number) { "TBD" }
        let(:bike) { Bike.new(serial_number: serial_number, serial_normalized_no_space: "something") }
        it "removes serial_normalized_no_space" do
          expect(bike.serial_number).to eq("unknown")
          expect(bike.made_without_serial).to eq(false)
          expect(bike.serial_normalized).to eq(nil)
          expect(bike.serial_normalized_no_space).to eq(nil)
        end
      end

      context "serials with spaces" do
        let(:serial_number) { "\n11 11  22 2  2 2 " }
        it "stores with spaces and without" do
          expect(bike.serial_number).to eq("11 11 22 2 2 2")
          expect(bike.made_without_serial).to eq(false)
          expect(bike.serial_normalized).to eq "11 11 22 2 2 2"
          expect(bike.serial_normalized_no_space).to eq "111122222"
        end
        context "special characters" do
          let(:serial_number) { "Some-Serial.  .Stuf?f" }
          it "stores with spaces and without" do
            expect(bike.serial_number).to eq("Some-Serial. .Stuf?f")
            expect(bike.made_without_serial).to eq(false)
            expect(bike.serial_normalized).to eq("50ME 5ER1A1 5TUF F")
            expect(bike.serial_normalized_no_space).to eq("50ME5ER1A15TUFF")
          end
        end
      end
    end

    context "actual tests for ascend and lightspeed" do
      let!(:bike_lightspeed_pos) { FactoryBot.create(:bike_lightspeed_pos) }
      let!(:bike_ascend_pos) { FactoryBot.create(:bike_ascend_pos) }
      it "scopes correctly" do
        # There was a factory bug where it was creating multiple ownerships
        expect(Ownership.where(bike_id: bike_lightspeed_pos.id).count).to eq 1
        expect(Ownership.count).to eq 2
        expect(bike_lightspeed_pos.pos_kind).to eq "lightspeed_pos"
        expect(bike_ascend_pos.pos_kind).to eq "ascend_pos"
        expect(Bike.lightspeed_pos.pluck(:id)).to eq([bike_lightspeed_pos.id])
        expect(Bike.ascend_pos.pluck(:id)).to eq([bike_ascend_pos.id])
      end
    end

    describe "registration_info" do
      describe "organization_affiliation" do
        let(:bike) { FactoryBot.create(:bike, :with_ownership, creation_registration_info: registration_info) }
        let(:registration_info) { {} }
        it "sets if searched" do
          expect(bike.organization_affiliation).to be_blank
          expect(bike.registration_info).to eq({})
          bike.update(organization_affiliation: "community_member")
          bike.reload
          expect(bike.registration_info).to eq({organization_affiliation: "community_member"}.as_json)
          expect(bike.organization_affiliation).to eq "community_member"
        end
        context "other info" do
          let(:registration_info) { {address: "717 Market St, SF", phone: "717.742.3423", organization_affiliation: "employee"} }
          let(:target_registration_info) { registration_info.as_json.merge("phone" => "7177423423") }
          it "uses correct value" do
            bike.reload
            # expect(bike.registration_info).to eq target_registration_info
            expect(bike.organization_affiliation).to eq "employee"
            bike.update(organization_affiliation: "student")
            bike.reload
            expect(bike.organization_affiliation).to eq "student"
            expect(bike.registration_info).to eq target_registration_info.merge(organization_affiliation: "student").as_json
          end
        end
      end

      describe "student_id" do
        let(:bike) { FactoryBot.create(:bike, :with_ownership, creation_registration_info: registration_info) }
        let(:registration_info) { {} }
        it "sets if searched" do
          expect(bike.student_id).to be_blank
          expect(bike.registration_info).to eq({})
          bike.update(student_id: "424242")
          bike.reload
          expect(bike.registration_info).to eq({student_id: "424242"}.as_json)
          expect(bike.student_id).to eq "424242"
        end
        context "with creation value" do
          let(:registration_info) { {street: "717 Market St, SF", phone: "7177423423", student_id: "CCCIIIIBBBBB"} }
          it "uses correct value" do
            bike.reload
            expect(bike.current_ownership&.id).to be_present
            bike.reload
            expect(bike.registration_info).to eq registration_info.as_json
            expect(bike.student_id).to eq "CCCIIIIBBBBB"
            expect(bike.phone).to eq "7177423423"
            expect(bike.registration_info).to eq registration_info.as_json
            bike.update(student_id: "66")
            bike.reload
            expect(bike.student_id).to eq "66"
            expect(bike.registration_info).to eq registration_info.merge(student_id: "66").as_json
          end
        end
      end
    end
  end

  describe "visible_by?" do
    let(:owner) { User.new }
    let(:superuser) { User.new(superuser: true) }
    it "is visible if not hidden" do
      bike = Bike.new
      expect(bike.visible_by?).to be_truthy
      expect(bike.visible_by?(User.new)).to be_truthy
    end
    context "user hidden" do
      it "is visible to owner" do
        bike = Bike.new(user_hidden: true)
        allow(bike).to receive(:owner).and_return(owner)
        allow(bike).to receive(:user_hidden).and_return(true)
        expect(bike.visible_by?(owner)).to be_truthy
        expect(bike.visible_by?(User.new)).to be_falsey
        expect(bike.visible_by?(superuser)).to be_truthy
      end
    end
    context "deleted?" do
      it "is not visible to owner" do
        bike = Bike.new(deleted_at: Time.current)
        allow(bike).to receive(:owner).and_return(owner)
        expect(bike.deleted?).to be_truthy
        expect(bike.visible_by?(owner)).to be_falsey
        expect(bike.visible_by?(User.new)).to be_falsey
        expect(bike.visible_by?(superuser)).to be_truthy
        bike.user_hidden = true
        expect(bike.visible_by?(superuser)).to be_truthy
      end
    end
  end

  describe "phoneable_by?" do
    let(:bike) { Bike.new }
    let(:user) { User.new }
    it "does not return anything if there isn't a stolen record or phone number" do
      expect(bike.phoneable_by?).to be_falsey
      expect(bike.phoneable_by?(User.new(superuser: true))).to be_falsey
    end

    context "bike has phone number" do
      let(:bike) { Bike.new(phone: "831289423") }
      let(:owner) { User.new(notification_unstolen: true) }
      let(:ownership) { Ownership.new(user: owner, current: true, claimed: true) }
      before { allow(bike).to receive(:current_ownership) { ownership } }

      it "is phoneable_by superuser" do
        expect(bike.phoneable_by?(User.new(superuser: true))).to be_truthy
        owner.notification_unstolen = false
        expect(bike.phoneable_by?(User.new(superuser: true))).to be_truthy
      end

      context "ambassador" do
        let(:user) { FactoryBot.create(:ambassador) }
        it "is not phoneable_by" do
          user.reload
          expect(user.ambassador?).to be_truthy
          expect(bike.phoneable_by?(user)).to be_falsey
          expect(bike.contact_owner?(user)).to be_truthy
        end
      end

      context "non-ambassador org with unstolen_notifications" do
        let(:user) { FactoryBot.create(:organization_member) }
        let(:organization) { user.organizations.first }
        it "is phoneable_by" do
          organization.update_attribute :enabled_feature_slugs, ["unstolen_notifications"]
          user.reload
          expect(bike.phoneable_by?(user)).to be_truthy
          expect(bike.contact_owner?(user)).to be_truthy
          owner.notification_unstolen = false
          expect(bike.phoneable_by?(user)).to be_falsey
          expect(bike.contact_owner?(user)).to be_falsey
        end
      end
    end

    context "stolen" do
      let(:stolen_record) { StolenRecord.new(phone: "7883747392", phone_for_users: false, phone_for_shops: false, phone_for_police: false) }
      let(:bike) { Bike.new(current_stolen_record: stolen_record) }

      it "returns true for superusers, even with everything false" do
        user.superuser = true
        expect(bike.phoneable_by?(user)).to be_truthy
      end

      it "returns true if phone_for_everyone" do
        stolen_record.phone_for_everyone = true
        expect(bike.current_stolen_record).to be_present
        expect(bike.phoneable_by?).to be_truthy
        expect(bike.phoneable_by?(user)).to be_truthy
      end

      it "returns true if phone_for_users" do
        stolen_record.phone_for_users = true
        expect(bike.phoneable_by?).to be_falsey
        expect(bike.phoneable_by?(user)).to be_truthy
      end

      it "returns true if shops can see it and user has shop membership" do
        allow(user).to receive(:has_shop_membership?).and_return(true)
        stolen_record.phone_for_shops = true
        expect(bike.phoneable_by?(user)).to be_truthy
        expect(bike.phoneable_by?(User.new)).to be_falsey
      end

      it "returns true if police can see it and user is police" do
        allow(user).to receive(:has_police_membership?).and_return(true)
        stolen_record.phone_for_police = true
        expect(bike.phoneable_by?(user)).to be_truthy
        expect(bike.phoneable_by?(User.new)).to be_falsey
      end
    end
  end

  describe "owner" do
    let(:delete_user) { FactoryBot.create(:user) }
    let!(:ownership) { FactoryBot.create(:ownership_claimed, user_id: delete_user.id) }
    let(:bike) { ownership.reload.bike }
    it "doesn't break if the owner is deleted" do
      expect(bike.current_ownership_id).to eq ownership.id
      expect(bike.owner&.id).to eq(delete_user.id)
      delete_user.delete
      expect(bike.reload.owner&.id).to eq(ownership.creator_id)
    end
  end

  describe "first_owner_email" do
    let(:ownership) { Ownership.new(owner_email: "foo@example.com") }
    let(:bike) { Bike.new }
    it "gets owner email from the first ownership" do
      allow(bike).to receive(:first_ownership) { ownership }
      expect(bike.first_owner_email).to eq("foo@example.com")
    end
  end

  describe "frame_size" do
    let(:bike) { Bike.new(frame_size: frame_size) }
    context "crap in size string" do
      let(:frame_size) { '19\\\\"' }
      it "removes crap" do
        bike.clean_frame_size
        expect(bike.frame_size_number).to eq(19)
        expect(bike.frame_size).to eq("19in")
        expect(bike.frame_size_unit).to eq("in")
      end
    end
    context "passed cm number" do
      let(:frame_size) { "Med/54cm" }
      it "figures out that it's cm" do
        bike.clean_frame_size
        expect(bike.frame_size_number).to eq(54)
        expect(bike.frame_size).to eq("54cm")
        expect(bike.frame_size_unit).to eq("cm")
      end
    end
    context "ordinal letter" do
      let(:frame_size) { "M" }
      before { bike.clean_frame_size }
      it "is cool with ordinal sizing" do
        expect(bike.frame_size).to eq("m")
        expect(bike.frame_size_unit).to eq("ordinal")
      end
      context "XXS" do
        let(:frame_size) { "xXs" }
        it "is cool with it" do
          expect(bike.frame_size).to eq("xxs")
          expect(bike.frame_size_unit).to eq("ordinal")
        end
      end
      context "XXL" do
        let(:frame_size) { "XXL" }
        it "is cool with it" do
          expect(bike.frame_size).to eq("xxl")
          expect(bike.frame_size_unit).to eq("ordinal")
        end
      end
    end

    context "ordinal string" do
      let(:frame_size) { "Med" }
      it "is sets on save" do
        bike.clean_frame_size
        expect(bike.frame_size).to eq("m")
        expect(bike.frame_size_unit).to eq("ordinal")
      end
    end
    context "passed things" do
      let(:bike) { FactoryBot.create(:bike, frame_size_number: "19.5sa", frame_size_unit: "in") }
      it "sets on save" do
        bike.reload
        expect(bike.frame_size_number).to eq(19.5)
        expect(bike.frame_size).to eq("19.5in")
        expect(bike.frame_size_unit).to eq("in")
      end
    end
  end

  describe "user?" do
    let(:bike) { Bike.new }
    let(:ownership) { Ownership.new }
    before { allow(bike).to receive(:current_ownership) { ownership } }
    it "returns false if ownership isn't claimed" do
      expect(bike.user?).to be_falsey
    end
    context "claimed" do
      let(:user) { User.new }
      let(:ownership) { Ownership.new(claimed: true, user: user) }
      it "returns true if ownership is claimed" do
        expect(bike.user?).to be_truthy
      end
    end
  end

  describe "claimable_by?" do
    context "already claimed" do
      it "returns false" do
        user = User.new
        bike = Bike.new
        allow(bike).to receive(:user?).and_return(true)
        expect(bike.claimable_by?(user)).to be_falsey
      end
    end
    context "can be claimed" do
      it "returns true" do
        user = User.new
        ownership = Ownership.new
        bike = Bike.new
        allow(bike).to receive(:current_ownership).and_return(ownership)
        allow(ownership).to receive(:user).and_return(user)
        allow(bike).to receive(:user?).and_return(false)
        expect(bike.claimable_by?(user)).to be_truthy
      end
    end
    context "no current_ownership" do # AKA Something is broken. Bikes should always have ownerships
      it "does not explode" do
        user = User.new
        bike = Bike.new
        expect(bike.claimable_by?(user)).to be_falsey
      end
    end
  end

  describe "cleaned_error_messages" do
    let(:errors) { ["Manufacturer can't be blank", "Bike can't be blank", "Association error Ownership wasn't saved. Are you sure the bike was created?"] }
    it "removes error messages we don't want to show users" do
      bike = Bike.new
      errors.each { |e| bike.errors.add(:base, e) }
      expect(bike.cleaned_error_messages.length).to eq(1)
    end
  end

  describe "status_humanized_translated" do
    let(:bike) { Bike.new(status: status) }
    let(:status) { "unregistered_parking_notification" }
    it "responds with status" do
      expect(bike.status_humanized).to eq "unregistered"
      expect(bike.status_humanized_translated).to eq "unregistered"
    end
    context "status_with_owner" do
      let(:status) { "status_with_owner" }
      it "responds with status" do
        expect(bike.status_humanized).to eq "with owner"
        expect(bike.status_humanized_translated).to eq "with owner"
      end
    end
  end

  describe "authorize_and_claim_for_user, authorized?" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership) }
    let(:creator) { bike.creator }
    let(:user) { FactoryBot.create(:user) }
    let(:superuser) { User.new(superuser: true) }

    context "un-organized" do
      context "no user" do
        it "returns false" do
          expect(bike.authorized?(nil)).to be_falsey
          expect(bike.authorize_and_claim_for_user(nil)).to be_falsey
          expect(bike.authorized?(superuser)).to be_truthy
        end
      end
      context "unauthorized" do
        it "returns false" do
          expect(bike.authorized?(user)).to be_falsey
          expect(bike.authorize_and_claim_for_user(user)).to be_falsey
        end
      end
      context "creator" do
        it "returns true" do
          expect(bike.authorized?(creator)).to be_truthy
          expect(bike.authorize_and_claim_for_user(creator)).to be_truthy
        end
      end
      context "claimed" do
        let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: user, creator: FactoryBot.create(:user_confirmed)) }
        let(:user) { FactoryBot.create(:user_confirmed) }
        it "returns true for user, not creator" do
          expect(bike.claimed?).to be_truthy
          expect(bike.authorized?(creator)).to be_falsey
          expect(bike.authorized?(user)).to be_truthy
          expect(bike.authorized?(user, no_superuser_override: true)).to be_truthy
          expect(bike.authorize_and_claim_for_user(creator)).to be_falsey
          expect(bike.authorize_and_claim_for_user(user)).to be_truthy
          expect(bike.authorized?(superuser)).to be_truthy
          expect(bike.authorized?(superuser, no_superuser_override: true)).to be_falsey
          expect(superuser.authorized?(bike)).to be_truthy
          expect(superuser.authorized?(bike, no_superuser_override: true)).to be_falsey
        end
      end
      context "claimed" do
        let(:superuser) { FactoryBot.create(:admin) }
        let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: superuser, creator: FactoryBot.create(:user_confirmed)) }
        it "returns true for user, not creator" do
          expect(bike.reload.current_ownership.creator_id).to_not eq superuser.id
          expect(bike.current_ownership.user_id).to eq superuser.id
          expect(bike.claimed?).to be_truthy
          expect(bike.authorized?(creator)).to be_falsey
          expect(bike.authorized?(superuser)).to be_truthy
          expect(bike.authorized?(superuser, no_superuser_override: true)).to be_truthy
          expect(bike.authorize_and_claim_for_user(creator)).to be_falsey
          expect(bike.authorize_and_claim_for_user(superuser)).to be_truthy
          expect(bike.authorized?(superuser)).to be_truthy
          expect(bike.authorized?(superuser, no_superuser_override: true)).to be_truthy
          expect(superuser.authorized?(bike, no_superuser_override: true)).to be_truthy
        end
      end
      context "claimable_by?" do
        let(:bike) { FactoryBot.create(:bike, :with_ownership, user: user) }
        it "marks claimed and returns true" do
          expect(bike.claimed?).to be_falsey
          expect(bike.owner).to eq creator
          expect(bike.authorize_and_claim_for_user(creator)).to be_truthy
          expect(bike.authorized?(user)).to be_truthy
          expect(bike.authorize_and_claim_for_user(user)).to be_truthy
          expect(bike.claimed?).to be_truthy
          expect(bike.authorize_and_claim_for_user(creator)).to be_falsey
          bike.reload
          expect(bike.owner).to eq user
          expect(bike.ownerships.count).to eq 1
        end
      end
    end
    context "creation organization" do
      let(:owner) { FactoryBot.create(:organization_member) }
      let(:organization) { owner.organizations.first }
      let(:can_edit_claimed) { false }
      let(:claimed) { false }
      let(:bike) do
        FactoryBot.create(:bike_organized,
          user: owner,
          creation_organization: organization,
          can_edit_claimed: can_edit_claimed,
          claimed: claimed)
      end
      let(:member) { FactoryBot.create(:organization_member, organization: organization) }
      before { expect(bike.creation_organization).to eq member.organizations.first }
      it "returns correctly for all sorts of convoluted things" do
        bike.reload
        expect(bike.creation_organization).to eq organization
        expect(bike.editable_organizations.pluck(:id)).to eq([organization.id])
        expect(bike.claimed?).to be_falsey
        expect(bike.authorize_and_claim_for_user(member)).to be_truthy
        expect(bike.authorize_and_claim_for_user(member)).to be_truthy
        expect(bike.claimed?).to be_falsey
        # And test authorized_by_organization?
        expect(bike.authorized_by_organization?).to be_truthy
        expect(member.authorized?(bike)).to be_truthy
        expect(bike.authorized_by_organization?(u: member)).to be_truthy
        expect(bike.authorized_by_organization?(u: member, org: organization)).to be_truthy
        expect(bike.authorized_by_organization?(org: organization)).to be_truthy
        expect(bike.authorized_by_organization?(u: member, org: Organization.new)).to be_falsey
        # If the member has multiple memberships, it should only work for the correct organization
        new_membership = FactoryBot.create(:membership_claimed, user: member)
        expect(bike.authorized_by_organization?).to be_truthy
        expect(bike.authorized_by_organization?(u: member)).to be_truthy
        expect(bike.authorized_by_organization?(u: member, org: new_membership.organization)).to be_falsey
        # It should be authorized for the owner, but not be authorized_by_organization
        expect(bike.authorized?(owner)).to be_truthy
        expect(bike.authorized_by_organization?(u: owner)).to be_falsey # Because this bike is authorized by owning it, not organization
        expect(bike.authorized_by_organization?(u: member)).to be_truthy # Sanity check - we haven't broken this
        # And it isn't authorized for a random user or a random org
        expect(bike.authorized_by_organization?(u: user)).to be_falsey
        expect(bike.authorized_by_organization?(u: user, org: organization)).to be_falsey
        expect(bike.authorized_by_organization?(org: Organization.new)).to be_falsey
        expect(bike.authorized?(user)).to be_falsey
        expect(bike.authorize_and_claim_for_user(user)).to be_falsey
        # Also test the post-claim authorization
        bike.authorize_and_claim_for_user(owner)
        expect(bike.authorized?(owner)).to be_truthy
        expect(bike.authorized_by_organization?(u: owner)).to be_falsey # Also doesn't work for user if bike is claimed
      end
      context "claimed" do
        let(:claimed) { true }
        before do
          bike.reload
          expect(bike.claimed?).to be_truthy
        end
        it "returns false" do
          expect(bike.organizations.pluck(:id)).to eq([organization.id])
          expect(bike.editable_organizations).to eq([])
          expect(bike.authorized?(member)).to be_falsey
          expect(member.authorized?(bike)).to be_falsey
          expect(bike.authorized_by_organization?).to be_falsey
          expect(bike.organized?).to be_truthy
          expect(bike.organized?(organization)).to be_truthy
          expect(bike.organized?(Organization.new)).to be_falsey
        end
        context "can_edit_claimed true" do
          let(:can_edit_claimed) { true }
          it "returns true" do
            expect(bike.owner).to eq owner
            expect(bike.editable_organizations.pluck(:id)).to eq([organization.id])
            expect(bike.authorized?(member)).to be_truthy
            expect(member.authorized?(bike)).to be_truthy
            expect(bike.authorized_by_organization?).to be_truthy
            expect(bike.claimed?).to be_truthy
            expect(bike.organized?).to be_truthy
            expect(bike.organized?(organization)).to be_truthy
            expect(bike.organized?(Organization.new)).to be_falsey
          end
        end
      end
      context "multiple ownerships" do
        let!(:ownership2) { FactoryBot.create(:ownership, bike: bike, creator: user) }
        it "returns false" do
          bike.reload
          expect(bike.claimed?).to be_falsey
          expect(bike.owner).to eq user
          expect(bike.ownerships.count).to eq 2
          expect(bike.authorized_by_organization?).to be_falsey
          expect(bike.authorized?(member)).to be_falsey
          expect(bike.authorize_and_claim_for_user(member)).to be_falsey
          expect(bike.claimed?).to be_falsey
        end
        context "can_edit_claimed true" do
          let(:can_edit_claimed) { true }
          it "returns truthy" do
            bike.reload
            expect(bike.claimed?).to be_falsey
            expect(bike.owner).to eq user
            expect(bike.ownerships.count).to eq 2
            expect(bike.authorized_by_organization?).to be_truthy
            expect(bike.authorized_by_organization?(org: organization)).to be_truthy
            expect(bike.authorized?(member)).to be_truthy
            expect(bike.authorize_and_claim_for_user(member)).to be_truthy
            expect(bike.claimed?).to be_falsey
          end
        end
      end
    end
    context "impound_record" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: user) }
      let(:impound_record) { FactoryBot.create(:impound_record, bike: bike, user: user) }
      it "returns truthy if impound_record is current unless user is organization_member" do
        expect(impound_record.bike_id).to eq bike.id
        expect(bike.reload.claimed?).to be_truthy
        expect(bike.impound_records.pluck(:id)).to eq([impound_record.id])
        expect(bike.current_impound_record_id).to eq impound_record.id
        expect(impound_record.reload.active?).to be_truthy
        expect(impound_record.user_id).to eq user.id
        expect(bike.status).to eq "status_impounded"
        expect(bike.status_humanized).to eq "found"
        expect(bike.status_humanized_translated).to eq "found"
        expect(bike.current_record&.id).to eq impound_record.id
        expect(bike.authorized?(user)).to be_truthy
        expect(bike.authorized?(superuser)).to be_truthy
      end
    end
    context "impound_record with organization" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership, user: user, claimed: claimed) }
      let(:claimed) { false }
      let(:impound_record) { FactoryBot.build(:impound_record_with_organization, bike: bike) }
      let(:organization) { impound_record.organization }
      let!(:organization_member) { FactoryBot.create(:organization_member, organization: organization) }
      it "returns falsey if impound record is current unless user is organization_member" do
        expect(bike.reload.claimed?).to be_falsey
        expect(bike.owner).to eq creator
        expect(bike.claimable_by?(user)).to be_truthy
        expect(bike.editable_organizations.pluck(:id)).to eq([])
        Sidekiq::Worker.clear_all
        Sidekiq::Testing.inline! do
          impound_record.save
          bike.reload
          expect(bike.status).to eq "status_impounded"
          expect(bike.serial_display).to eq "Hidden"
          expect(bike.editable_organizations.pluck(:id)).to eq([organization.id]) # impound org can edit
          expect(bike.authorize_and_claim_for_user(creator)).to be_falsey
          expect(bike.authorized?(organization_member)).to be_truthy
          expect(bike.current_impound_record_id).to eq impound_record.id
          impound_record.impound_record_updates.create(kind: "retrieved_by_owner", user: organization_member)
        end
        impound_record.reload
        expect(impound_record.resolved?).to be_truthy
        bike.reload
        expect(bike.editable_organizations.pluck(:id)).to eq([]) # No longer impounded by that org
        expect(bike.status).to eq "status_with_owner"
        expect(bike.authorize_and_claim_for_user(creator)).to be_truthy
        expect(bike.authorized?(user)).to be_truthy
        expect(bike.authorized?(superuser)).to be_truthy
      end
      context "ownership claimed" do
        let(:claimed) { true }
        it "returns falsey" do
          expect(bike.reload.claimed?).to be_truthy
          expect(bike.authorized?(creator)).to be_falsey
          expect(bike.authorized?(user)).to be_truthy
          expect(bike.editable_organizations.pluck(:id)).to eq([])
          Sidekiq::Worker.clear_all
          Sidekiq::Testing.inline! do
            impound_record.save
            bike.reload
            expect(bike.status).to eq "status_impounded"
            expect(bike.editable_organizations.pluck(:id)).to eq([organization.id]) # impound org can edit
            expect(bike.authorized?(user)).to be_falsey
            expect(bike.authorized?(organization_member)).to be_truthy
            impound_record.impound_record_updates.create(kind: "retrieved_by_owner", user: organization_member)
          end
          impound_record.reload
          expect(impound_record.resolved?).to be_truthy
          bike.reload
          expect(bike.editable_organizations.pluck(:id)).to eq([]) # No longer impounded by that org
          expect(bike.status).to eq "status_with_owner"
          expect(bike.authorized?(user)).to be_truthy
          expect(bike.authorized?(organization_member)).to be_falsey # Because no organization membership
          expect(bike.authorized?(superuser)).to be_truthy
        end
      end
    end
  end

  describe "authorized_by_organization?" do
    let(:user) { FactoryBot.create(:user) }
    let(:organization) { FactoryBot.create(:organization) }
    let!(:organization_member) { FactoryBot.create(:organization_member, organization: organization) }
    let(:organization_membership2) { FactoryBot.create(:membership, user: organization_member) }
    let!(:organization2) { organization_membership2.organization }
    let(:bike) { FactoryBot.create(:bike_organized, user: user, claimed: true, creation_organization: organization, can_edit_claimed: false) }
    let!(:other_organization) { FactoryBot.create(:bike_organization, bike: bike, can_edit_claimed: true, organization: organization2) }
    it "checks the passed organization" do
      bike.reload
      expect(bike.claimed?).to be_truthy
      expect(bike.editable_organizations.pluck(:id)).to eq([organization2.id])
      expect(bike.authorized_by_organization?(u: user)).to be_falsey # Because the user is the owner
      expect(bike.authorized_by_organization?).to be_truthy
      expect(bike.authorized_by_organization?(u: organization_member)).to be_truthy
      expect(bike.authorized_by_organization?(org: organization)).to be_falsey
      expect(bike.authorized_by_organization?(u: organization_member, org: organization)).to be_falsey
      expect(bike.authorized_by_organization?(org: organization2)).to be_truthy
      expect(bike.authorized_by_organization?(u: organization_member, org: organization2)).to be_truthy
      # Also, if passed a user, the user must be a member of the organization that was passed
      expect(bike.authorized_by_organization?(u: FactoryBot.create(:user), org: organization2)).to be_falsey
    end
  end

  describe "contact_owner_user?" do
    let(:owner_email) { "party@party.com" }
    let(:creator) { FactoryBot.create(:user, email: "notparty@party.com") }
    let(:bike) { FactoryBot.create(:bike, owner_email: owner_email, creator: creator) }
    let!(:ownership) { FactoryBot.create(:ownership_claimed, bike: bike, owner_email: owner_email, creator: creator) }
    let(:admin) { User.new(superuser: true) }
    it "is true" do
      expect(bike.reload.contact_owner_user?).to be_truthy
      expect(bike.contact_owner_email).to eq owner_email
    end
    context "ownership not claimed" do
      let!(:ownership) { FactoryBot.create(:ownership, bike: bike, owner_email: owner_email, creator: creator) }
      it "is false" do
        expect(bike.reload.current_ownership.claimed?).to be_falsey
        expect(bike.contact_owner_user?).to be false
        expect(bike.contact_owner_email).to eq "notparty@party.com"
        expect(bike.contact_owner_user?(admin)).to be true
        expect(bike.contact_owner_email(admin)).to eq "party@party.com"
      end
      context "registered as stolen" do
        let(:bike) { FactoryBot.create(:stolen_bike, owner_email: owner_email, creator: creator) }
        it "is truthy" do
          expect(bike.status_stolen?).to be_truthy
          expect(bike.contact_owner_user?).to be true
          expect(bike.contact_owner_email).to eq owner_email
        end
      end
    end
    context "organizations" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:user) { FactoryBot.create(:organization_member, organization: organization) }
      let(:user_unorganized) { User.new }
      let(:owner) { User.new }
      let(:organization_unstolen) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[unstolen_notifications]) }
      let(:membership) { FactoryBot.create(:membership, user: user, organization: organization_unstolen) }
      it "is truthy for the organization with unstolen" do
        allow(bike).to receive(:owner) { owner }
        expect(bike.contact_owner?).to be_falsey
        expect(bike.contact_owner?(user)).to be_falsey
        expect(bike.contact_owner?(user, organization)).to be_falsey
        expect(BikeDisplayer.display_contact_owner?(bike, user)).to be_falsey

        # Add user to the unstolen org
        expect(membership.reload).to be_present
        user.reload
        expect(bike.contact_owner?(user)).to be_truthy
        expect(bike.contact_owner?(user, organization_unstolen)).to be_truthy
        expect(BikeDisplayer.display_contact_owner?(bike, user)).to be_falsey
        # But still false if passing old organization
        expect(bike.contact_owner?(user, organization)).to be_falsey
        expect(BikeDisplayer.display_contact_owner?(bike, user)).to be_falsey
        # Passing the organization doesn't permit the user to do something unpermitted
        expect(bike.contact_owner?(user_unorganized, organization_unstolen)).to be_falsey
        expect(BikeDisplayer.display_contact_owner?(bike, user_unorganized)).to be_falsey
        # And if the owner has set notification_unstolen to false, block organization access
        owner.notification_unstolen = false
        expect(bike.contact_owner?(user, organization_unstolen)).to be_falsey
      end
      context "organization direct_unclaimed_notifications registration" do
        let(:organization_direct_email) { FactoryBot.create(:organization, direct_unclaimed_notifications: true) }
        let!(:ownership) { nil } # Block duplicate ownership creation
        let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization_unstolen, owner_email: owner_email, creator: creator) }
        let(:bike2) { FactoryBot.create(:bike_organized, creation_organization: organization_direct_email, owner_email: owner_email, creator: creator) }
        it "is truthy" do
          expect(bike.reload.current_ownership.claimed?).to be false
          expect(bike.current_ownership.organization.direct_unclaimed_notifications?).to be false
          expect(bike.contact_owner?).to be false
          expect(bike.contact_owner?(user)).to be false
          expect(bike.contact_owner?(user, organization)).to be false
          expect(BikeDisplayer.display_contact_owner?(bike, user)).to be false
          # Check superusers
          expect(BikeDisplayer.display_contact_owner?(bike, admin)).to be false
          expect(bike.contact_owner?(admin, organization)).to be false
          expect(bike.current_ownership.organization_direct_unclaimed_notifications?).to be false
          expect(bike.contact_owner_user?(admin, organization)).to be true
          # Add user to the unstolen org
          expect(membership.reload).to be_present
          user.reload
          expect(bike.contact_owner?(user)).to be true
          expect(bike.contact_owner?(user, organization_unstolen)).to be true
          expect(BikeDisplayer.display_contact_owner?(bike, user)).to be false # Handled through org panel
          expect(bike.contact_owner_user?(user, organization)).to be false
          expect(bike.contact_owner_email(user)).to eq "notparty@party.com"

          # And now for the direct owner
          expect(bike2.reload.current_ownership.claimed?).to be false
          expect(bike2.current_ownership.organization_direct_unclaimed_notifications?).to be true
          expect(bike2.contact_owner?(user)).to be true
          expect(bike2.contact_owner?(user, organization_unstolen)).to be true
          expect(BikeDisplayer.display_contact_owner?(bike2, user)).to be false # Handled through org panel
          expect(bike2.contact_owner_user?(user, organization)).to be true
          expect(bike2.contact_owner_email(user)).to eq "party@party.com"
          # Random user doesn't have contact_owner? - but still directed to user email, because direct_unclaimed_notification
          other_user = User.new
          expect(bike2.contact_owner?(other_user, organization_unstolen)).to be false
          expect(bike2.contact_owner_user?(other_user, organization)).to be true
          expect(bike2.contact_owner_email(other_user)).to eq "party@party.com"
        end
      end
    end
    context "with owner with notification_unstolen false" do
      it "is falsey" do
        allow(bike).to receive(:owner) { User.new(notification_unstolen: false) }
        expect(bike.contact_owner?).to be false
        expect(bike.contact_owner?(User.new)).to be false
        expect(bike.contact_owner?(admin)).to be false
        expect(BikeDisplayer.display_contact_owner?(bike, admin)).to be false
      end
    end
  end

  describe "set_user_hidden" do
    let(:ownership) { FactoryBot.create(:ownership) }
    let(:bike) { ownership.bike }
    it "marks updates ownership user hidden, marks self hidden" do
      bike.marked_user_hidden = true
      bike.set_user_hidden
      expect(bike.user_hidden).to be_truthy
      expect(ownership.reload.user_hidden).to be_truthy
    end

    context "already user hidden" do
      let(:ownership) { FactoryBot.create(:ownership, user_hidden: true) }
      it "unmarks user hidden, saves ownership and marks self unhidden on save" do
        bike.update(user_hidden: true, marked_user_unhidden: true)
        bike.reload
        expect(bike.user_hidden).to be_falsey
        expect(ownership.reload.user_hidden).to be_falsey
      end
    end
  end

  describe "bike_sticker and no_bike_sticker" do
    let(:organization1) { FactoryBot.create(:organization) }
    let(:organization2) { FactoryBot.create(:organization) }
    let(:bike1) { FactoryBot.create(:bike_organized, creation_organization: organization1) }
    let(:bike2) { FactoryBot.create(:bike_organized, creation_organization: organization1) }
    let!(:bike3) { FactoryBot.create(:bike_organized, creation_organization: organization1) }
    let!(:bike4) { FactoryBot.create(:bike_organized, creation_organization: organization2) }
    let!(:bike_sticker1) { FactoryBot.create(:bike_sticker_claimed, bike: bike1, organization: organization1) }
    let!(:bike_sticker2) { FactoryBot.create(:bike_sticker_claimed, bike: bike2, organization: nil) }
    it "returns appropriately" do
      expect(bike2.bike_sticker?).to be_truthy
      expect(bike2.bike_sticker?(organization1.id)).to be_falsey
      expect(bike2.bike_sticker?(organization2.id)).to be_falsey
      # And with an bike_sticker with an organization
      expect(bike1.bike_sticker?).to be_truthy
      expect(bike1.bike_sticker?(organization1.id)).to be_truthy
      expect(bike1.bike_sticker?(organization2.id)).to be_falsey
      # We only accept numerical ids here
      expect(bike1.bike_sticker?(organization1.slug)).to be_falsey
      # Class method scope/search for bike codes
      expect(Bike.bike_sticker.pluck(:id)).to match_array([bike1.id, bike2.id])
      expect(organization1.bikes.pluck(:id)).to match_array([bike1.id, bike2.id, bike3.id])
      expect(organization1.bikes.bike_sticker.pluck(:id)).to match_array([bike1.id, bike2.id])
      expect(organization1.bikes.bike_sticker(organization1.id).pluck(:id)).to eq([bike1.id])
      expect(organization2.bikes.bike_sticker.pluck(:id)).to eq([])
      expect(Bike.bike_sticker(organization1.id).pluck(:id)).to eq([bike1.id])
      # And class method scope/search for bikes without code
      expect(Bike.no_bike_sticker.pluck(:id)).to match_array([bike3.id, bike4.id])
      expect(organization1.bikes.no_bike_sticker.pluck(:id)).to match_array([bike3.id])
      # I got lazy on implementing this. We don't really need to pass organization_id in, and I couldn't figure out the join,
      # So I just skipped it. Leaving these specs just in case this becomes a thing we need - Seth
      # expect(organization1.bikes.no_bike_sticker(organization1.id).pluck(:id)).to eq([bike2.id, bike3.id])
      # expect(organization2.bikes.no_bike_sticker.pluck(:id)).to eq([bike4.id])
      # expect(Bike.no_bike_sticker(organization1.id).pluck(:id)).to eq([bike2.id])
    end
  end

  describe "#normalized_email" do
    it "sets normalized owner email" do
      bike = Bike.new(owner_email: "  somethinG@foo.orG")
      expect(bike.send(:normalized_email)).to eq("something@foo.org")
    end

    context "confirmed secondary email" do
      it "sets email to the primary email" do
        user_email = FactoryBot.create(:user_email)
        user = user_email.user
        bike = FactoryBot.build(:bike, owner_email: user_email.email)
        expect(user.email).to_not eq user_email.email
        expect(bike.owner_email).to eq user_email.email
        expect(bike.send(:normalized_email)).to eq user.email
      end
    end

    context "unconfirmed secondary email" do
      it "uses passed owner_email" do
        user_email = FactoryBot.create(:user_email, confirmation_token: "123456789")
        user = user_email.user
        expect(user_email.unconfirmed?).to be_truthy
        expect(user.email).to_not eq user_email.email
        bike = FactoryBot.build(:bike, owner_email: user_email.email)
        expect(bike.owner_email).to eq user_email.email
        bike.save
        expect(bike.owner_email).to eq user_email.email
      end
    end
  end

  describe "serial_display" do
    it "returns the serial" do
      expect(Bike.new(serial_number: "AAbbCC").serial_display).to eq "AAbbCC"
    end
    context "abandoned" do
      it "only returns the serial if we should show people the serial" do
        # We're hiding serial numbers for abandoned bikes to provide a method of verifying ownership
        bike = Bike.new(serial_number: "something", status: "unregistered_parking_notification")
        expect(bike.authorized?(nil)).to be_falsey
        expect(bike.serial_hidden?).to be_truthy
        expect(bike.serial_display).to eq "Hidden"
        allow(bike).to receive(:authorized?) { true }
        expect(bike.serial_display(User.new)).to eq "something"
      end
    end
    context "impounded" do
      it "only returns the serial if we should show people the serial" do
        # We're hiding serial numbers for abandoned bikes to provide a method of verifying ownership
        bike = Bike.new(serial_number: "something", status: "status_impounded")
        expect(bike.serial_hidden?).to be_truthy
        expect(bike.serial_display).to eq "Hidden"
      end
    end
    context "unknown" do
      it "returns unknown" do
        bike = Bike.new(serial_number: "unknown")
        expect(bike.serial_display).to eq("Unknown")
      end
    end
    context "Made without serial" do
      it "returns made_without_serial" do
        bike = Bike.new(made_without_serial: true)
        bike.normalize_serial_number
        expect(bike.serial_display).to eq("Made without serial")
      end
    end
    context "impound_record" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, serial_number: "Hello Party") }
      let!(:impound_record) { FactoryBot.create(:impound_record, bike: bike) }
      let(:bike_impounded) { impound_record.bike }
      let(:impound_user) { impound_record.user }
      it "is hidden, except for the owner and org" do
        expect(bike.reload.status).to eq "status_impounded"
        expect(bike.status_humanized).to eq "found"
        # individual users don't get the ability to override ownership access -
        # only organization impounded records do
        expect(impound_record.authorized?(impound_user)).to be_truthy
        expect(bike.authorized?(bike.user)).to be_truthy
        expect(bike.authorized?(impound_user)).to be_falsey
        expect(bike.serial_display).to eq "Hidden"
        expect(bike.serial_display(bike.user)).to eq "Hello Party"
        expect(bike.serial_display(impound_user)).to eq "Hello Party"
      end
      context "organized" do
        let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, bike: bike) }
        it "is hidden, except for the owner and org" do
          expect(impound_record.authorized?(impound_user)).to be_truthy
          expect(bike.reload.status).to eq "status_impounded"
          expect(bike.status_humanized).to eq "impounded"
          expect(bike.authorized?(bike.user)).to be_falsey
          expect(bike.authorized?(impound_user)).to be_truthy
          expect(bike.serial_display).to eq "Hidden"
          expect(bike.serial_display(bike.user)).to eq "Hello Party"
          expect(bike.serial_display(impound_user)).to eq "Hello Party"
        end
      end
    end
  end

  describe "address_source" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership, creation_registration_info: registration_info) }
    let(:registration_info) { {street: "2864 Milwaukee Ave"} }
    context "no address" do
      it "returns nil" do
        expect(Bike.new.registration_address_source).to be_blank
      end
    end
    context "address set on bike" do
      it "returns bike_update" do
        expect(bike.reload.registration_address_source).to eq "initial_creation"
        bike.update(street: "1313 N Milwaukee Ave ", city: " Chicago", zipcode: " 66666", latitude: 43.9, longitude: -88.7, address_set_manually: true)
        expect(bike.registration_address_source).to eq "bike_update"
        expect(bike.latitude).to eq 43.9
        expect(bike.latitude_public).to eq 43.9
        expect(bike.street).to eq "1313 N Milwaukee Ave"
        expect(bike.city).to eq "Chicago"
        expect(bike.zipcode).to eq "66666"
      end
    end
    context "b_param" do
      let!(:b_param) { FactoryBot.create(:b_param, created_bike_id: bike.id, params: {bike: registration_info}) }
      it "returns creation_information" do
        bike.reload
        expect(bike.registration_address_source).to eq "initial_creation"
        expect(bike.registration_info).to eq registration_info.as_json
      end
      context "user with address address_set_manually" do
        let(:user) { FactoryBot.create(:user, :in_vancouver, address_set_manually: true) }
        let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: user, city: "Lancaster", zipcode: 17601) }
        it "returns user address" do
          bike.reload
          expect(bike.registration_address_source).to eq "user"
          expect(bike.address_hash["city"]).to eq "Lancaster" # Because it's set on the bike
          expect(bike.registration_address(true)).to eq user.address_hash
          expect(bike.registration_address["city"]).to eq "Vancouver"
        end
      end
      context "with stolen record" do
        let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership, creation_registration_info: registration_info) }
        it "returns initial_creation" do
          expect(bike.reload.registration_address_source).to eq "initial_creation"
        end
      end
    end
  end

  describe "avery_exportable?" do
    context "unclaimed bike, with owner email" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:user) { FactoryBot.create(:user_confirmed, name: "some name") }
      let(:bike) do
        FactoryBot.create(:bike_organized,
          creation_organization: organization,
          owner_email: user.email,
          creator: user,
          creation_registration_info: {street: "102 Washington Pl", city: "State College"})
      end
      # let(:ownership) { FactoryBot.create(:ownership, creator: user, user: nil, bike: bike) }
      include_context :geocoder_real
      it "is exportable" do
        # Referencing the same address and the same cassette from a different spec, b/c I'm terrible ;)
        VCR.use_cassette("organization_export_worker-avery") do
          bike.reload.update(updated_at: Time.current)
          expect(bike.reload.user&.id).to eq user.id
          # We test that the bike has a location saved
          expect(bike.registration_address_source).to eq "initial_creation"
          expect(bike.registration_address(true)).to eq({street: "102 Washington Pl", city: "State College"}.as_json)
          expect(bike.latitude).to be_present
          expect(bike.longitude).to be_present
          expect(bike.owner_name).to eq "some name"
          expect(bike.registration_address["street"]).to eq "102 Washington Pl"
          expect(bike.avery_exportable?).to be_truthy
          FactoryBot.create(:impound_record_with_organization, bike: bike, organization: organization)
          bike.update(updated_at: Time.current) # Bump current_impound_record
          expect(bike.reload.current_impound_record_id).to be_present
          expect(bike.avery_exportable?).to be_falsey
        end
      end
    end
  end

  describe "registration_address" do
    let(:bike) { Bike.new }
    let(:b_param) { BParam.new }
    it "returns nil when no b_param and with a b_param without address" do
      expect(bike.registration_address).to eq({})
      allow(bike).to receive(:b_params) { [b_param] }
      expect(bike.registration_address).to eq({})
    end
    context "with user with address" do
      let(:country) { Country.united_states }
      let(:state) { FactoryBot.create(:state, name: "New York", abbreviation: "NY") }
      let(:user) { FactoryBot.create(:user, country_id: country.id, state_id: state.id, city: "New York", street: "278 Broadway", zipcode: "10007", address_set_manually: true) }
      let(:bike) { ownership.bike }
      let(:ownership) { FactoryBot.create(:ownership_claimed, user: user) }
      it "returns the user's address" do
        expect(user.address_hash).to eq default_location_registration_address
        bike.reload
        expect(bike.registration_address_source).to eq "user"
        expect(bike.registration_address(true)).to eq default_location_registration_address
      end
      context "ownership creator" do
        let(:ownership) { FactoryBot.create(:ownership_claimed, creator: user, user: FactoryBot.create(:user_confirmed)) }
        it "returns nothing" do
          expect(user.address_hash).to eq default_location_registration_address
          expect(bike.user).to_not eq user
          expect(bike.registration_address_source).to be_blank
          expect(bike.registration_address.values.compact).to eq([])
        end
      end
    end
  end

  describe "phone" do
    let(:bike) { Bike.new }
    let(:user) { FactoryBot.create(:user, phone: "765.987.1234") }
    context "user" do
      let(:ownership) { Ownership.new(user: user) }
      it "returns users phone" do
        allow(bike).to receive(:current_ownership) { ownership }
        expect(ownership.first?).to be_truthy
        expect(user.phone).to eq "7659871234"
        expect(bike.phone).to eq "7659871234"
      end
    end
    context "b_param" do
      let(:ownership) { Ownership.new(registration_info: {phone: "888.888.8888"}) }
      before do
        allow(bike).to receive(:current_ownership) { ownership }
      end
      it "returns the phone" do
        allow(bike).to receive(:first_ownership) { ownership }
        expect(bike.phone).to eq "888.888.8888"
      end
    end
    context "creator" do
      let(:ownership) { Ownership.new(creator: user) }
      it "returns nil" do
        allow(bike).to receive(:current_ownership) { ownership }
        expect(bike.phone).to be_nil
      end
    end
  end

  describe "set_paints" do
    it "returns true if paint is a color" do
      FactoryBot.create(:color, name: "Bluety")
      bike = Bike.new
      allow(bike).to receive(:paint_name).and_return(" blueTy")
      expect { bike.set_paints }.not_to change(Paint, :count)
      expect(bike.paint).to be_nil
    end
    it "removes paint id if paint_name is nil" do
      paint = FactoryBot.create(:paint)
      bike = FactoryBot.build(:bike, paint_id: paint.id)
      bike.paint_name = ""
      bike.save
      expect(bike.paint).to be_nil
    end
    it "sets the paint if it exists" do
      FactoryBot.create(:paint, name: "poopy pile")
      bike = Bike.new
      allow(bike).to receive(:paint_name).and_return("Poopy PILE  ")
      expect { bike.set_paints }.not_to change(Paint, :count)
      expect(bike.paint.name).to eq("poopy pile")
    end
    it "creates a new paint and set it otherwise" do
      bike = Bike.new
      bike.paint_name = ["Food Time SOOON"]
      expect { bike.set_paints }.to change(Paint, :count).by(1)
      expect(bike.paint.name).to eq("food time sooon")
    end
  end

  describe "mnfg_name" do
    let(:manufacturer) { FactoryBot.create(:manufacturer, name: "SE Racing (S E Bikes)") }
    let(:bike) { FactoryBot.create(:bike, manufacturer: manufacturer) }
    it "is the simple_name" do
      expect(bike.reload.mnfg_name).to eq "SE Racing"
    end
    context "manufacturer_other blank" do
      let(:bike) { FactoryBot.create(:bike, manufacturer: Manufacturer.other, manufacturer_other: " ") }
      it "is nil" do
        expect(bike.manufacturer_other).to eq nil
        expect(bike.mnfg_name).to eq "Other"
      end
    end
  end

  describe "cache_photo" do
    context "existing photo" do
      it "caches the photo" do
        bike = FactoryBot.create(:bike)
        FactoryBot.create(:public_image, imageable: bike)
        bike.reload.update(updated_at: Time.current)
        expect(bike.reload.thumb_path).not_to be_nil
      end
    end
  end

  describe "components_cache_array" do
    it "caches the components" do
      bike = FactoryBot.create(:bike)
      manufacturer = FactoryBot.create(:manufacturer)
      FactoryBot.create(:component, bike: bike, year: 2025, manufacturer: manufacturer, component_model: "Cool model")
      bike.save
      expect(bike.cached_data).to match("2025 #{manufacturer.name} Cool model")
    end
  end

  describe "cached_description_and_stolen_description" do
    context "current_stolen_record with lat and long" do
      it "saves the stolen description to all description and set stolen_rec_id" do
        stolen_record = FactoryBot.create(:stolen_record, theft_description: "some theft description", latitude: 40.7143528, longitude: -74.0059731)
        bike = stolen_record.bike
        bike.update(description: "I love my bike")
        expect(bike.reload.all_description).to eq("I love my bike some theft description")
        expect(bike.occurred_at).to eq stolen_record.reload.date_stolen
        expect(bike.current_record&.id).to eq stolen_record.id
      end
    end
    context "no current_stolen_record" do
      it "sets the description and unsets current_stolen_record_id" do
        bike = Bike.new(current_stolen_record_id: 99999, description: "lalalala")
        bike.current_stolen_record = nil

        expect(bike.current_stolen_record_id).not_to be_present
        expect(bike.send(:cached_description_and_stolen_description)).to eq("lalalala")
      end
    end
  end

  describe "cache_bike" do
    let(:wheel_size) { FactoryBot.create(:wheel_size) }
    let(:bike) { FactoryBot.create(:bike, rear_wheel_size: wheel_size) }
    let!(:stolen_record) { FactoryBot.create(:stolen_record, bike: bike) }
    let(:target_cached_string) { "#{bike.mnfg_name} Sail 1999 #{bike.primary_frame_color.name} #{bike.secondary_frame_color.name} #{bike.tertiary_frame_color.name} #{bike.frame_material_name} 56foo #{bike.frame_model} #{wheel_size.name} wheel unicycle" }
    it "caches all the bike parts" do
      bike.update(year: 1999, frame_material: "steel",
        secondary_frame_color_id: FactoryBot.create(:color).id,
        tertiary_frame_color_id: FactoryBot.create(:color).id,
        handlebar_type: "bmx",
        propulsion_type: "sail",
        cycle_type: "unicycle",
        frame_size: "56", frame_size_unit: "foo",
        frame_model: "Some model")
      bike.reload
      expect(bike.cached_data).to eq target_cached_string
      expect(bike.current_stolen_record_id).to eq(stolen_record.id)
    end
  end

  describe "set_calculated_unassociated_attributes extra_registration_number" do
    let(:bike) { FactoryBot.create(:bike, serial_number: serial, extra_registration_number: extra_registration_number) }
    let(:serial) { "xxxx-zzzzz-VVVVVV" }
    let(:extra_registration_number) { " extra " }
    it "strips extra_registration_number" do
      expect(bike.extra_registration_number).to eq "extra"
    end
    context "same as serial" do
      let(:extra_registration_number) { " #{serial.downcase}" }
      it "removes extra_registration_number" do
        expect(bike.extra_registration_number).to be_nil
      end
    end
    context "is serial:serial as serial" do
      let(:extra_registration_number) { "SERIAL:#{serial.upcase}" }
      it "removes extra_registration_number" do
        expect(bike.extra_registration_number).to be_nil
      end
    end
  end

  describe "calculated_listing_order" do
    let(:bike) { Bike.new }
    it "is 1/1000 of the current timestamp" do
      expect(bike.calculated_listing_order).to eq(Time.current.to_i / 1000000)
    end

    it "is the current stolen record date stolen * 1000" do
      allow(bike).to receive(:status).and_return("status_stolen")
      stolen_record = StolenRecord.new
      yesterday = Time.current - 1.days
      allow(stolen_record).to receive(:date_stolen).and_return(yesterday)
      allow(bike).to receive(:current_stolen_record).and_return(stolen_record)
      expect(bike.calculated_listing_order).to eq(yesterday.to_time.to_i)
    end

    it "is the updated_at" do
      last_week = Time.current - 7.days
      bike.updated_at = last_week
      allow(bike).to receive(:stock_photo_url).and_return("https://some_photo.cum")
      expect(bike.calculated_listing_order).to eq(last_week.to_time.to_i / 10000)
    end

    context "stolen_record date" do
      let(:bike) { FactoryBot.create(:stolen_bike) }
      it "does not get out of integer errors" do
        expect(bike.reload.listing_order).to be_within(1).of bike.current_stolen_record.date_stolen.to_i
      end
    end

    context "impound_record date" do
      let(:bike) { FactoryBot.create(:impounded_bike) }
      it "does not get out of integer errors" do
        expect(bike.reload.current_impound_record.impounded_at.to_i).to be_present
        expect(bike.listing_order).to be_within(1).of bike.current_impound_record.impounded_at.to_i
      end
    end
  end

  describe "title_string" do
    it "escapes correctly" do
      bike = Bike.new(frame_model: "</title><svg/onload=alert(document.cookie)>")
      allow(bike).to receive(:mnfg_name).and_return("baller")
      allow(bike).to receive(:type).and_return("bike")
      expect(bike.title_string).not_to match("</title><svg/onload=alert(document.cookie)>")
      expect(bike.title_string.length).to be > 5
    end
  end

  describe "validated_organization_id" do
    let(:bike) { Bike.new }
    context "valid organization" do
      let(:organization) { FactoryBot.create(:organization) }
      context "slug" do
        it "returns true" do
          expect(bike.validated_organization_id(organization.slug)).to eq organization.id
        end
      end
      context "id" do
        it "returns true" do
          expect(bike.validated_organization_id(organization.id)).to eq organization.id
        end
      end
    end
    context "unable to find organization" do
      it "adds an error to the bike" do
        expect(bike.validated_organization_id("some org")).to be_nil
        expect(bike.errors[:organizations].to_s).to match(/not found/)
        expect(bike.errors[:organizations].to_s).to match(/some org/)
      end
    end
  end

  describe "image_url" do
    it "is nil" do
      expect(Bike.new.image_url).to be_blank
    end
    context "with stock photo" do
      let(:bike) { Bike.new(stock_photo_url: stock_photo_url) }
      let(:stock_photo_url) { "https://bikebook.s3.amazonaws.com/uploads/Fr/10251/12_codacomp_bl.jpg" }
      it "is stock_photo_url small" do
        expect(bike.image_url).to eq stock_photo_url
        expect(bike.image_url(:small)).to eq stock_photo_url # Doesn't do sizes for stock photos
      end
    end
    context "with public_images" do
      let(:bike) { FactoryBot.create(:bike) }
      let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }
      before { bike.update(updated_at: Time.current) } # bump thumb path
      it "is the public image" do
        expect(bike.reload.thumb_path).to be_present
        expect(Bike::REMOTE_IMAGE_FALLBACK_URLS).to be_falsey
        expect(bike.image_url).to eq public_image.image_url
        expect(bike.image_url(:medium)).to eq public_image.image_url(:medium)
      end
      it "with REMOTE_IMAGE_FALLBACK_URLS true return URL" do
        stub_const("BikeAttributable::REMOTE_IMAGE_FALLBACK_URLS", true)
        expect(Bike::REMOTE_IMAGE_FALLBACK_URLS).to be_truthy
        # Approximates what happens for local dev with remote images
        allow_any_instance_of(ImageUploader).to receive(:blank?) { true }
        image_url = public_image.image_url
        expect(bike.reload.image_url).to eq image_url.gsub("http://test.host", "https://files.bikeindex.org")
      end
    end
    context "with missing public_image" do
      let(:bike) { FactoryBot.create(:bike) }
      # This happens sometimes when images are deleted
      before { bike.update_column(:thumb_path, "https://files.bikeindex.org/uploads/Pu/33333/adsf.jpg") }
      it "is nil" do
        expect(Bike::REMOTE_IMAGE_FALLBACK_URLS).to be_falsey
        expect(bike.reload.image_url).to be_blank
      end
    end
  end

  describe "assignment of bike_organization_ids" do
    let(:bike) { FactoryBot.create(:bike_organized) }
    let(:organization) { bike.organizations.first }
    let(:bike_organization) { bike.bike_organizations.first }
    let(:organization2) { FactoryBot.create(:organization) }
    before { expect(bike.bike_organization_ids).to eq([organization.id]) }
    context "no organization_ids" do
      it "removes bike organizations" do
        expect(bike.bike_organization_ids).to eq([organization.id])
        bike.bike_organization_ids = ""
        # Acts as paranoid
        bike_organization.reload
        expect(bike_organization.deleted_at).to be_within(1.second).of Time.current
        expect(bike.reload.bike_organization_ids).to eq([])

        bike.bike_organization_ids = [organization.id]
        expect(bike.reload.bike_organization_ids).to eq([organization.id]) # despite uniqueness validation
      end
    end
    context "different organization" do
      it "adds organization and removes existing" do
        bike.bike_organization_ids = "#{organization2.id}, "
        expect(bike.reload.bike_organization_ids).to eq([organization2.id])
      end
    end
  end

  describe "#alert_image_url" do
    context "given no current_stolen_record" do
      it "returns nil" do
        bike = FactoryBot.create(:bike, :with_image, current_stolen_record: nil)
        expect(bike.alert_image_url).to be_nil
      end
    end

    context "given no public images" do
      it "returns nil" do
        bike = FactoryBot.create(:bike)
        stolen_record = FactoryBot.create(:stolen_record, bike: bike)
        bike.update(current_stolen_record: stolen_record)
        expect(bike.current_stolen_record).to be_present
        expect(bike.public_images).to be_empty
        expect(bike.alert_image_url).to be_nil
      end
    end

    context "given a current_stolen_record and public bike images" do
      it "returns the alert_image url" do
        bike = FactoryBot.create(:stolen_bike, :with_image)
        expect(bike.alert_image_url).to match(%r{https?://.+/bike-#{bike.id}.jpg})
      end
    end
  end

  describe "messages_count" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
    let(:owner) { bike.owner }
    let(:user) { FactoryBot.create(:user) }
    it "is 0" do
      expect(bike.reload.messages_count).to eq 0
    end
    context "theft_survey" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, :with_stolen_record) }
      let!(:notification) { Notification.create(user: user, kind: "theft_survey_4_2022", notifiable: bike.current_stolen_record) }
      it "is 1" do
        expect(bike.reload.messages_count).to eq 1
      end
    end
    context "graduated_notification" do
      let!(:graduated_notification) { FactoryBot.create(:graduated_notification, :marked_remaining) }
      let(:bike) { graduated_notification.bike }
      it "is 1" do
        expect(bike.reload.messages_count).to eq 1
      end
    end
    context "everything but graduated" do
      let!(:notification) { FactoryBot.create(:notification, kind: "bike_possibly_found", bike: bike) }
      let!(:parking_notification) { FactoryBot.create(:parking_notification, :retrieved, bike: bike) }
      let!(:feedback) { FactoryBot.create(:feedback_serial_update_request, bike: bike) }
      let!(:user_alert) { FactoryBot.create(:user_alert_stolen_bike_without_location, bike: bike, user: owner) }
      it "counts all them" do
        expect(bike.reload.messages_count).to eq 4
      end
    end
  end

  describe "#set_location_info" do
    let!(:usa) { Country.united_states }

    context "given a current_stolen_record and no bike location info" do
      let(:bike) { FactoryBot.create(:stolen_bike_in_chicago) }
      let(:stolen_record) { bike.current_stolen_record }
      let(:street_address) { "1300 W 14th Pl" }
      let(:abbr_address) { "Chicago, IL 60608, US" }
      let(:full_address) { "#{street_address}, #{abbr_address}" }
      before { stolen_record.skip_geocoding = false }
      it "takes location from the current stolen record" do
        expect(stolen_record.street).to eq street_address
        expect(stolen_record.address(force_show_address: true)).to eq(full_address)
        expect(stolen_record.address).to eq(abbr_address)

        bike.reload
        # Ensure we aren't geocoding ;)
        allow(bike).to receive(:bike_index_geocode) { fail "should not have called geocoding" }
        stolen_record.save
        bike.save
        expect(StolenRecord.unscoped.where(bike_id: bike.id).count).to eq 1

        expect(bike.to_coordinates).to eq(stolen_record.to_coordinates)
        expect(bike.city).to eq(stolen_record.city)
        expect(bike.street).to be_present
        expect(bike.zipcode).to eq(stolen_record.zipcode)
        expect(bike.address).to eq(full_address)
        expect(bike.country).to eq(stolen_record.country)
      end
      context "removing location from the stolen_record" do
        # When displaying searches for stolen bikes, it's critical we honor the stolen record's data
        # ... or else unexpected things happen
        it "blanks the location on the bike" do
          expect(stolen_record.address(force_show_address: true)).to eq(full_address)
          expect(bike.address).to eq "1300 W 14th Pl, Chicago, IL 60608, US"
          allow(bike).to receive(:bike_index_geocode) { fail "should not have called geocoding" }
          bike.reload
          stolen_record.reload
          # stolen_record.skip_geocoding = false
          Sidekiq::Testing.inline! do
            stolen_record.attributes = {street: "", city: "", zipcode: ""}
            expect(stolen_record.should_be_geocoded?).to be_truthy
            stolen_record.save
            expect(stolen_record.street).to be_nil
            expect(stolen_record.city).to be_nil
            expect(stolen_record.zipcode).to be_nil
          end
          stolen_record.reload
          bike.reload
          # Doesn't have coordinates, see geocodeable for additional information
          expect(stolen_record.to_coordinates.compact).to eq([])
          expect(stolen_record.address_hash.compact).to eq({country: "US", state: "IL"}.as_json)
          expect(stolen_record.address(force_show_address: true)).to eq "IL, US"
          expect(stolen_record.should_be_geocoded?).to be_falsey

          expect(bike.address_hash).to eq({country: "US", state: "IL", street: nil, city: nil, zipcode: nil, latitude: nil, longitude: nil}.as_json)
          expect(bike.to_coordinates.compact).to eq([])
          expect(bike.should_be_geocoded?).to be_falsey
          expect(bike.registration_address_source).to be_blank
        end
      end
      context "given a parking notification" do
        it "it still uses the stolen_record" do
          expect(bike.to_coordinates).to eq(stolen_record.to_coordinates)
          parking_notification = FactoryBot.create(:parking_notification, :in_los_angeles, bike: bike)
          bike.reload
          expect(bike.current_impound_record).to_not be_present
          expect(bike.current_parking_notification).to eq parking_notification
          expect(bike.to_coordinates).to eq(stolen_record.to_coordinates)
          expect(bike.address_hash).to eq stolen_record.address_hash
          expect(bike.address_set_manually).to be_falsey
          expect(bike.registration_address_source).to be_blank
          expect(bike.status).to eq "status_stolen"
          expect(bike.send(:authorization_requires_organization?)).to be_falsey
        end
      end
    end

    context "given no current_stolen_record" do
      it "takes location from the creation org" do
        org = FactoryBot.create(:organization, :in_nyc)
        bike = FactoryBot.build(:bike, creation_organization: org)

        bike.set_location_info

        expect(bike.city).to eq("New York")
        expect(bike.zipcode).to eq("10011")
        expect(bike.country).to eq(usa)
        expect(bike.street).to be_present
      end
      context "with a blank street" do
        let(:bike) { FactoryBot.create(:bike, street: "  ") }
        it "is nil" do
          expect(bike.reload.street).to be_nil
        end
      end
    end

    context "given no creation org location" do
      let(:city) { "New York" }
      let(:zipcode) { "10011" }
      let(:user) { FactoryBot.create(:user_confirmed, zipcode: zipcode, country: usa, city: city) }
      let(:ownership) { FactoryBot.create(:ownership, user: user, creator: user, registration_info: {zipcode: "99999", country: "US", city: city, street: "main main street"}) }
      let(:bike) { ownership.bike }
      it "takes location from the creation state" do
        bike.update(updated_at: Time.current)
        bike.reload # Set current_ownership_id
        expect(user.reload.street).to be_blank
        expect(user.address_set_manually).to be_falsey
        expect(user.to_coordinates.compact.length).to eq 2 # User still has coordinates, even though no street
        expect(bike.reload.current_ownership_id).to eq ownership.id
        expect(bike.current_ownership.address_hash[:latitude]).to be_blank
        expect(bike.registration_address_source).to eq "initial_creation"
        expect(bike.registration_address(true)["zipcode"]).to eq "99999"

        bike.reload
        bike.skip_geocoding = false
        bike.set_location_info
        expect(bike.skip_geocoding).to be_falsey

        expect(bike.city).to eq(city)
        expect(bike.zipcode).to eq("99999")
        expect(bike.country).to eq(usa)
        expect(bike.street).to eq "main main street"
      end
      context "user street is present" do
        let(:user) { FactoryBot.create(:user_confirmed, :in_nyc, address_set_manually: true) }
        it "uses user address" do
          bike.update(updated_at: Time.current)
          bike.reload
          expect(user.reload.street).to be_present
          expect(user.address_set_manually).to be_truthy
          expect(user.to_coordinates.compact.length).to eq 2 # User still has coordinates, even though no street
          expect(bike.reload.current_ownership_id).to eq ownership.id
          expect(bike.registration_address_source).to eq "user"

          bike.reload
          bike.address_set_manually = true
          bike.street = nil
          bike.skip_geocoding = false
          bike.set_location_info
          expect(bike.skip_geocoding).to be_truthy

          expect(bike.address_hash).to eq user.address_hash
          expect(bike.street).to eq user.street
          expect(bike.address_set_manually).to be_falsey # Because it's set by the user
        end
      end
    end
  end
end
