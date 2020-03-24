require "rails_helper"

RSpec.describe Bike, type: :model do
  it_behaves_like "bike_searchable"

  describe "scopes" do
    it "default scopes to created_at desc" do
      expect(Bike.all.to_sql).to eq(Bike.unscoped.where(example: false, hidden: false, deleted_at: nil).order("listing_order desc").to_sql)
    end
    it "scopes to only stolen bikes" do
      expect(Bike.stolen.to_sql).to eq(Bike.where(stolen: true).to_sql)
    end
    it "non_stolen scopes to only non_stolen bikes" do
      expect(Bike.non_stolen.to_sql).to eq(Bike.where(stolen: false).to_sql)
    end
    it "non_abandoned scopes to only non_abandoned bikes" do
      expect(Bike.non_abandoned.to_sql).to eq(Bike.where(abandoned: false).to_sql)
    end
    it "abandoned scopes to only abandoned bikes" do
      expect(Bike.abandoned.to_sql).to eq(Bike.where(abandoned: true).to_sql)
    end
    it "recovered_records default scopes to created_at desc" do
      bike = FactoryBot.create(:bike)
      expect(bike.recovered_records.to_sql).to eq(StolenRecord.unscoped.where(bike_id: bike.id, current: false).order("recovered_at desc").to_sql)
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
    context "given a bike made with no serial number" do
      no_serials = [
        "custom bike no serial has a unique frame design",
        "custom built",
        "custom",
      ]
      no_serials.each do |value|
        it "('#{value}') sets the 'made_without_serial' state correctly" do
          bike = FactoryBot.build(:bike, serial_number: value)
          bike.normalize_serial_number
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
        "unknown",
      ]
      unknown_serials.each do |value|
        it "('#{value}') sets the 'unknown' state correctly" do
          bike = FactoryBot.build(:bike, serial_number: value)
          bike.normalize_serial_number
          expect(bike.serial_number).to eq("unknown")
          expect(bike.made_without_serial).to eq(false)
          expect(bike.serial_normalized).to eq(nil)
        end
      end
    end
  end

  context "actual tests for ascend and lightspeed" do
    let!(:bike_lightspeed_pos) { FactoryBot.create(:bike_lightspeed_pos) }
    let!(:bike_ascend_pos) { FactoryBot.create(:bike_ascend_pos) }
    it "scopes correctly" do
      expect(bike_lightspeed_pos.pos_kind).to eq "lightspeed_pos"
      expect(bike_ascend_pos.pos_kind).to eq "ascend_pos"
      expect(Bike.lightspeed_pos.pluck(:id)).to eq([bike_lightspeed_pos.id])
      expect(Bike.ascend_pos.pluck(:id)).to eq([bike_ascend_pos.id])
    end
  end

  describe ".possibly_found_with_match" do
    it "returns stolen bikes with a matching normalized serial on another abandoned bike" do
      pair0 = [
        FactoryBot.create(:bike, stolen: true, abandoned: true, serial_number: "He10o"),
        FactoryBot.create(:bike, stolen: true, abandoned: true, serial_number: "He10o"),
      ]

      pair1 = [
        FactoryBot.create(:bike, stolen: true, serial_number: "he110"),
        FactoryBot.create(:bike, abandoned: true, serial_number: "HEllO"),
      ]

      pair2 = [
        FactoryBot.create(:bike, stolen: true, serial_number: "1100ll"),
        FactoryBot.create(:bike, abandoned: true, serial_number: "IIOO11"),
      ]

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
        FactoryBot.create(:external_registry_bike, serial_number: "He10o"),
      ]

      pair1 = [
        FactoryBot.create(:stolen_bike_in_amsterdam, serial_number: "he110"),
        FactoryBot.create(:external_registry_bike, serial_number: "He1lo"),
      ]

      pair2 = [
        FactoryBot.create(:stolen_bike_in_amsterdam, serial_number: "1100ll"),
        FactoryBot.create(:external_registry_bike, serial_number: "IIOO11"),
      ]

      results = Bike.possibly_found_externally_with_match(country_iso: "NL")
      expect(results.length).to eq(2)

      result_ids = results.map { |pair| pair.map(&:id) }
      expect(result_ids).to_not include(pair0.map(&:id))
      expect(result_ids).to match_array([pair1.map(&:id), pair2.map(&:id)])
    end
  end

  describe "visible_by" do
    let(:owner) { User.new }
    let(:superuser) { User.new(superuser: true) }
    it "is visible if not hidden" do
      bike = Bike.new
      expect(bike.visible_by).to be_truthy
      expect(bike.visible_by(User.new)).to be_truthy
    end
    context "hidden" do
      it "isn't visible by user or owner" do
        bike = Bike.new(hidden: true)
        allow(bike).to receive(:owner).and_return(owner)
        allow(bike).to receive(:user_hidden).and_return(false)
        expect(bike.visible_by(owner)).to be_falsey
        expect(bike.visible_by(User.new)).to be_falsey
        expect(bike.visible_by(superuser)).to be_truthy
      end
    end
    context "user hidden" do
      it "is visible to owner" do
        bike = Bike.new(hidden: true)
        allow(bike).to receive(:owner).and_return(owner)
        allow(bike).to receive(:user_hidden).and_return(true)
        expect(bike.visible_by(owner)).to be_truthy
        expect(bike.visible_by(User.new)).to be_falsey
        expect(bike.visible_by(superuser)).to be_truthy
      end
    end
    context "deleted?" do
      it "is not visible to owner" do
        bike = Bike.new(deleted_at: Time.current)
        allow(bike).to receive(:owner).and_return(owner)
        expect(bike.deleted?).to be_truthy
        expect(bike.visible_by(owner)).to be_falsey
        expect(bike.visible_by(User.new)).to be_falsey
        expect(bike.visible_by(superuser)).to be_truthy
        bike.hidden = true
        expect(bike.visible_by(superuser)).to be_truthy
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
      let(:bike) { Bike.new(stolen: true, current_stolen_record: stolen_record) }

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
    it "doesn't break if the owner is deleted" do
      delete_user = FactoryBot.create(:user)
      ownership = FactoryBot.create(:ownership, user_id: delete_user.id)
      ownership.mark_claimed
      bike = ownership.bike
      expect(bike.owner).to eq(delete_user)
      delete_user.delete
      ownership.reload
      expect(bike.owner).to eq(ownership.creator)
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
      it "is cool with ordinal sizing" do
        bike.clean_frame_size
        expect(bike.frame_size).to eq("m")
        expect(bike.frame_size_unit).to eq("ordinal")
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

  describe "authorize_and_claim_for_user, authorized?" do
    let(:bike) { ownership.bike }
    let(:creator) { ownership.creator }
    let(:user) { FactoryBot.create(:user) }

    context "un-organized" do
      let(:ownership) { FactoryBot.create(:ownership) }
      context "no user" do
        it "returns false" do
          expect(bike.authorized?(nil)).to be_falsey
          expect(bike.authorize_and_claim_for_user(nil)).to be_falsey
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
        let(:ownership) { FactoryBot.create(:ownership_claimed) }
        let(:user) { ownership.user }
        it "returns true for user, not creator" do
          expect(bike.claimed?).to be_truthy
          expect(bike.authorized?(creator)).to be_falsey
          expect(bike.authorized?(user)).to be_truthy
          expect(bike.authorize_and_claim_for_user(creator)).to be_falsey
          expect(bike.authorize_and_claim_for_user(user)).to be_truthy
        end
      end
      context "claimable_by?" do
        let(:ownership) { FactoryBot.create(:ownership, user: user) }
        it "marks claimed and returns true" do
          expect(ownership.claimed?).to be_falsey
          expect(bike.claimed?).to be_falsey
          expect(ownership.owner).to eq creator
          expect(bike.authorize_and_claim_for_user(creator)).to be_truthy
          expect(bike.authorized?(user)).to be_truthy
          expect(bike.authorize_and_claim_for_user(user)).to be_truthy
          expect(bike.claimed?).to be_truthy
          expect(bike.authorize_and_claim_for_user(creator)).to be_falsey
          ownership.reload
          expect(ownership.owner).to eq user
          expect(bike.ownerships.count).to eq 1
        end
      end
    end
    context "creation organization" do
      let(:owner) { FactoryBot.create(:organization_member) }
      let(:organization) { owner.organizations.first }
      let(:can_edit_claimed) { false }
      let(:ownership) do
        FactoryBot.create(:ownership_organization_bike,
                          user: owner,
                          organization: organization,
                          can_edit_claimed: can_edit_claimed)
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
        before do
          ownership.mark_claimed
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
  end

  describe "authorized_by_organization?" do
    let(:user) { FactoryBot.create(:user) }
    let(:organization) { FactoryBot.create(:organization) }
    let!(:organization_member) { FactoryBot.create(:organization_member, organization: organization) }
    let(:organization_membership2) { FactoryBot.create(:membership, user: organization_member) }
    let!(:organization2) { organization_membership2.organization }
    let(:ownership) { FactoryBot.create(:ownership_organization_bike, user: user, claimed: true, organization: organization, can_edit_claimed: false) }
    let(:bike) { ownership.bike }
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

  describe "impound" do
    let(:bike) { FactoryBot.create(:bike) }
    let(:organization) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: "impound_bikes") }
    let(:user) { FactoryBot.create(:organization_member, organization: organization) }
    it "impounds the bike, returns record" do
      expect(bike.impound(user, organization: organization)).to be_truthy
      bike.reload
      expect(bike.impounded?).to be_truthy
    end
    context "bike impounded by same organization" do
      let(:user2) { FactoryBot.create(:organization_member, organization: organization) }
      let!(:impound_record) { FactoryBot.create(:impound_record, bike: bike, user: user2, organization: organization) }
      it "returns true, doesn't create a new record" do
        expect(bike.impounded?).to be_truthy
        expect(bike.impound(user, organization: organization)).to be_truthy
        bike.reload
        expect(bike.impounded?).to be_truthy
        expect(bike.impound_records.count).to eq 1
        expect(bike.impound_records.first.user).to eq user2
      end
    end
    context "passed organization user isn't permitted for" do
      let(:organization2) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: "impound_bikes") }
      it "returns with an error" do
        impound_record = bike.impound(user, organization: organization2)
        expect(impound_record.valid?).to be_falsey
        expect(impound_record.errors.full_messages.to_s).to match(/permission/)
        bike.reload
        expect(bike.impound_records.count).to eq 0
      end
    end
    context "bike impounded by different organization" do
      let(:organization2) { FactoryBot.create(:organization_with_paid_features, enabled_feature_slugs: "impound_bikes") }
      let(:user2) { FactoryBot.create(:organization_member, organization: organization2) }
      let!(:impound_record) { bike.impound(user2) }
      it "returns with an error" do
        expect(impound_record.organization).to eq organization2
        expect(bike.impounded?).to be_truthy
        impound_record2 = bike.impound(user, organization: organization)
        expect(impound_record2.valid?).to be_falsey
        expect(impound_record2.errors.full_messages.to_s).to match(/already/)
        bike.reload
        expect(bike.impound_records.count).to eq 1
      end
    end
    context "user not permitted" do
      let(:user) { FactoryBot.create(:user_confirmed) }
      it "returns with an error" do
        impound_record = bike.impound(user, organization: organization)
        expect(impound_record.valid?).to be_falsey
        expect(impound_record.errors.full_messages.to_s).to match(/permission/)
        bike.reload
        expect(bike.impound_records.count).to eq 0
      end
    end
  end

  describe "display_contact_owner?" do
    let(:bike) { Bike.new }
    let(:admin) { User.new(superuser: true) }
    it "is falsey if bike doesn't have stolen record" do
      allow(bike).to receive(:owner) { User.new }
      expect(bike.contact_owner?).to be_falsey
      expect(bike.contact_owner?(User.new)).to be_falsey
      expect(bike.contact_owner?(admin)).to be_truthy
      expect(bike.display_contact_owner?).to be_falsey
    end
    context "stolen bike" do
      let(:bike) { Bike.new(stolen: true, current_stolen_record: StolenRecord.new) }
      it "is truthy" do
        expect(bike.contact_owner?).to be_falsey
        expect(bike.contact_owner?(User.new)).to be_truthy
        expect(bike.display_contact_owner?).to be_truthy
      end
    end
  end

  describe "contact_owner_user?" do
    let(:owner_email) { "party@party.com" }
    let(:creator) { FactoryBot.create(:user, email: "notparty@party.com") }
    let(:bike) { FactoryBot.create(:bike, owner_email: owner_email, creator: creator) }
    let!(:ownership) { FactoryBot.create(:ownership_claimed, bike: bike, owner_email: owner_email, creator: creator) }
    it "is true" do
      expect(bike.contact_owner_user?).to be_truthy
      expect(bike.contact_owner_email).to eq owner_email
    end
    context "ownership not claimed" do
      let!(:ownership) { FactoryBot.create(:ownership, bike: bike, owner_email: owner_email, creator: creator) }
      it "is false" do
        expect(bike.contact_owner_user?).to be_falsey
        expect(bike.contact_owner_email).to eq "notparty@party.com"
      end
      context "registered as stolen" do
        let(:bike) { FactoryBot.create(:stolen_bike, owner_email: owner_email, creator: creator) }
        it "is truthy" do
          expect(bike.stolen?).to be_truthy
          expect(bike.contact_owner_user?).to be_truthy
          expect(bike.contact_owner_email).to eq owner_email
        end
      end
    end
    context "organizations" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:user) { FactoryBot.create(:organization_member, organization: organization) }
      let(:user_unorganized) { User.new }
      let(:owner) { User.new }
      let(:organization_unstolen) do
        o = FactoryBot.create(:organization)
        o.update_attribute :enabled_feature_slugs, %w[unstolen_notifications]
        o
      end
      it "is truthy for the organization with unstollen" do
        allow(bike).to receive(:owner) { owner }
        expect(bike.contact_owner?).to be_falsey
        expect(bike.contact_owner?(user)).to be_falsey
        expect(bike.contact_owner?(user, organization)).to be_falsey
        expect(bike.display_contact_owner?(user)).to be_falsey
        # Add user to the unstolen org
        FactoryBot.create(:membership, user: user, organization: organization_unstolen)
        user.reload
        expect(bike.contact_owner?(user)).to be_truthy
        expect(bike.contact_owner?(user, organization_unstolen)).to be_truthy
        expect(bike.display_contact_owner?(user)).to be_falsey
        # But still false if passing old organization
        expect(bike.contact_owner?(user, organization)).to be_falsey
        expect(bike.display_contact_owner?(user)).to be_falsey
        # Passing the organization doesn't permit the user to do something unpermitted
        expect(bike.contact_owner?(user_unorganized, organization_unstolen)).to be_falsey
        expect(bike.display_contact_owner?(user_unorganized)).to be_falsey
        # And if the owner has set notification_unstolen to false, block organization access
        owner.notification_unstolen = false
        expect(bike.contact_owner?(user, organization_unstolen)).to be_falsey
      end
    end
    context "with owner with notification_unstolen false" do
      let(:admin) { User.new(superuser: true) }
      it "is falsey" do
        allow(bike).to receive(:owner) { User.new(notification_unstolen: false) }
        expect(bike.contact_owner?).to be_falsey
        expect(bike.contact_owner?(User.new)).to be_falsey
        expect(bike.contact_owner?(admin)).to be_falsey
        expect(bike.display_contact_owner?(admin)).to be_falsey
      end
    end
  end

  describe "user_hidden" do
    it "is true if bike is hidden and ownership is user hidden" do
      bike = Bike.new(hidden: true)
      ownership = Ownership.new(user_hidden: true)
      allow(bike).to receive(:current_ownership).and_return(ownership)
      expect(bike.user_hidden).to be_truthy
    end
    it "is false otherwise" do
      bike = Bike.new(hidden: true)
      expect(bike.user_hidden).to be_falsey
    end
  end

  describe "set_user_hidden" do
    let(:ownership) { FactoryBot.create(:ownership) }
    let(:bike) { ownership.bike }
    it "marks updates ownership user hidden, marks self hidden" do
      bike.marked_user_hidden = true
      bike.set_user_hidden
      expect(bike.hidden).to be_truthy
      expect(ownership.reload.user_hidden).to be_truthy
    end

    context "already user hidden" do
      let(:ownership) { FactoryBot.create(:ownership, user_hidden: true) }
      it "unmarks user hidden, saves ownership and marks self unhidden on save" do
        bike.update_attributes(hidden: true, marked_user_unhidden: true)
        bike.reload
        expect(bike.hidden).to be_falsey
        expect(ownership.reload.user_hidden).to be_falsey
      end
    end
  end

  describe "bike_sticker and no_bike_sticker" do
    let(:organization1) { FactoryBot.create(:organization) }
    let(:organization2) { FactoryBot.create(:organization) }
    let(:bike1) { FactoryBot.create(:bike_organized, organization: organization1) }
    let(:bike2) { FactoryBot.create(:bike_organized, organization: organization1) }
    let!(:bike3) { FactoryBot.create(:bike_organized, organization: organization1) }
    let!(:bike4) { FactoryBot.create(:bike_organized, organization: organization2) }
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

  describe "find_current_stolen_record" do
    it "returns the last current stolen record if bike is stolen" do
      @bike = Bike.new
      first_stolen_record = StolenRecord.new
      second_stolen_record = StolenRecord.new
      allow(first_stolen_record).to receive(:current).and_return(true)
      allow(second_stolen_record).to receive(:current).and_return(true)
      allow(@bike).to receive(:stolen).and_return(true)
      allow(@bike).to receive(:stolen_records).and_return([first_stolen_record, second_stolen_record])
      expect(@bike.find_current_stolen_record).to eq(second_stolen_record)
    end

    it "is false if the bike isn't stolen" do
      @bike = Bike.new
      allow(@bike).to receive(:stolen).and_return(false)
      expect(@bike.find_current_stolen_record).to be_falsey
    end
  end

  describe "set_mnfg_name" do
    let(:manufacturer_other) { Manufacturer.new(name: "Other") }
    let(:manufacturer) { Manufacturer.new(name: "Mnfg name") }
    it "returns the value of manufacturer_other if manufacturer is other" do
      bike = Bike.new(manufacturer: manufacturer_other, manufacturer_other: "Other manufacturer name")
      bike.set_mnfg_name
      expect(bike.mnfg_name).to eq("Other manufacturer name")
    end

    it "returns the name of the manufacturer if it isn't other" do
      bike = Bike.new(manufacturer: manufacturer)
      bike.set_mnfg_name
      expect(bike.mnfg_name).to eq("Mnfg name")
    end

    context "malicious" do
      let(:bike) { Bike.new(manufacturer: manufacturer_other, manufacturer_other: '<a href="bad_site.js">stuff</a>') }
      it "removes bad things" do
        bike.set_mnfg_name
        expect(bike.mnfg_name).to eq("stuff")
      end
    end

    context "manufacturer with parens" do
      let(:manufacturer) { FactoryBot.create(:manufacturer, name: "SE Racing (S E Bikes)") }
      let(:bike) { FactoryBot.build(:bike, manufacturer: manufacturer) }
      it "returns Just SE Bikes (and does it on save)" do
        bike.save
        expect(bike.mnfg_name).to eq("SE Racing")
      end
    end
  end

  describe "type" do
    it "returns the cycle type name" do
      bike = FactoryBot.create(:bike, cycle_type: "trailer")
      expect(bike.type).to eq("bike trailer")
    end
  end

  describe "video_embed_src" do
    it "returns false if there is no video_embed" do
      @bike = Bike.new
      allow(@bike).to receive(:video_embed).and_return(nil)
      expect(@bike.video_embed_src).to be_nil
    end

    it "returns just the url of the video from a youtube iframe" do
      youtube_share = '
          <iframe width="560" height="315" src="//www.youtube.com/embed/Sv3xVOs7_No" frameborder="0" allowfullscreen></iframe>
        '
      @bike = Bike.new
      allow(@bike).to receive(:video_embed).and_return(youtube_share)
      expect(@bike.video_embed_src).to eq("//www.youtube.com/embed/Sv3xVOs7_No")
    end

    it "returns just the url of the video from a vimeo iframe" do
      vimeo_share = '<iframe src="http://player.vimeo.com/video/13094257" width="500" height="281" frameborder="0" webkitAllowFullScreen mozallowfullscreen allowFullScreen></iframe><p><a href="http://vimeo.com/13094257">Fixed Gear Kuala Lumpur, RatsKL Putrajaya</a> from <a href="http://vimeo.com/user3635109">irmanhilmi</a> on <a href="http://vimeo.com">Vimeo</a>.</p>'
      @bike = Bike.new
      allow(@bike).to receive(:video_embed).and_return(vimeo_share)
      expect(@bike.video_embed_src).to eq("http://player.vimeo.com/video/13094257")
    end
  end

  describe "#normalize_emails" do
    it "sets normalized owner email" do
      bike = Bike.new(owner_email: "  somethinG@foo.orG")
      bike.normalize_emails
      expect(bike.owner_email).to eq("something@foo.org")
    end

    context "confirmed secondary email" do
      it "sets email to the primary email" do
        user_email = FactoryBot.create(:user_email)
        user = user_email.user
        bike = FactoryBot.build(:bike, owner_email: user_email.email)
        expect(user.email).to_not eq user_email.email
        expect(bike.owner_email).to eq user_email.email
        bike.normalize_emails
        expect(bike.owner_email).to eq user.email
      end
    end

    context "unconfirmed secondary email" do
      it "sets owner email to primary email (on save)" do
        user_email = FactoryBot.create(:user_email, confirmation_token: "123456789")
        user = user_email.user
        expect(user_email.unconfirmed).to be_truthy
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
        bike = Bike.new(serial_number: "something", abandoned: true)
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
  end

  describe "pg search" do
    it "returns a bike which has a matching part of its description" do
      bike = FactoryBot.create(:bike, description: "Phil wood hub")
      FactoryBot.create(:bike)
      expect(Bike.text_search("phil wood hub").pluck(:id)).to eq([bike.id])
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
      let(:user) { FactoryBot.create(:user, country_id: country.id, state_id: state.id, city: "New York", street: "278 Broadway", zipcode: "10007") }
      let(:bike) { ownership.bike }
      let(:ownership) { FactoryBot.create(:ownership_claimed, user: user) }
      let(:target_address) { default_location_registration_address.merge("country" => "US") } # Annoying discrepancy
      it "returns the user's address" do
        expect(user.address_hash).to eq target_address
        expect(bike.registration_address).to eq target_address
      end
      context "ownership creator" do
        let(:ownership) { FactoryBot.create(:ownership_claimed, creator: user) }
        it "returns nothing" do
          expect(user.address_hash).to eq target_address
          expect(bike.registration_address).to eq({})
        end
      end
    end
    context "with registration_address" do
      let!(:b_param) { FactoryBot.create(:b_param, created_bike_id: bike.id, params: b_param_params) }
      let(:bike) { FactoryBot.create(:bike) }
      let(:b_param_params) { { bike: { address: "2864 Milwaukee Ave" } } }
      let(:target) { { address: "2864 N Milwaukee Ave", city: "Chicago", state: "IL", zipcode: "60618", country: "USA", latitude: 41.933238, longitude: -87.71476299999999 } }
      include_context :geocoder_real
      it "returns the fetched address" do
        expect(bike.b_params.pluck(:id)).to eq([b_param.id])
        bike.reload
        VCR.use_cassette("bike-fetch_formatted_address") do
          expect(bike.registration_address).to eq target.as_json
        end
        b_param.reload
        # Just check that we stored it, since lazily not testing this anywhere else
        expect(b_param.params["formatted_address"]).to eq target.as_json
      end
      context "with multiple b_params" do
        let!(:b_param_params) { { formatted_address: target, bike: { address: "2864 Milwaukee Ave" } } }
        let!(:b_param2) { FactoryBot.create(:b_param, created_bike_id: bike.id, params: { bike: { address: "" } }) }
        it "gets the one that has an address, doesn't lookup if formatted_address stored" do
          expect(bike.b_params.pluck(:id)).to match_array([b_param2.id, b_param.id])
          bike.reload
          expect(bike.registration_address).to eq target.as_json
        end
      end
    end
  end

  describe "owner_name" do
    let(:bike) { Bike.new }
    let(:user) { User.new(name: "Fun McGee") }
    context "user" do
      let(:ownership) { Ownership.new(user: user) }
      it "returns users name" do
        allow(bike).to receive(:current_ownership) { ownership }
        expect(ownership.first?).to be_truthy
        expect(bike.owner_name).to eq "Fun McGee"
      end
    end
    context "creator" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:user) { FactoryBot.create(:user_confirmed, name: "Stephanie Example") }
      let(:new_owner) { FactoryBot.create(:user, name: "Sally Stuff", email: "sally@example.com") }
      let(:ownership) { FactoryBot.create(:ownership_organization_bike, claimed: false, user: nil, creator: user, organization: organization, owner_email: "sally@example.com") }
      let(:bike) { ownership.bike }
      it "falls back to creator" do
        ownership.reload
        expect(ownership.claimed?).to be_falsey
        expect(bike.user).to be_blank
        expect(bike.owner_name).to eq "Stephanie Example"
        ownership.user = new_owner
        # Creator name is a fallback, if the bike is claimed we want to use the person who has claimed it
        ownership.mark_claimed
        bike.reload
        ownership.reload
        expect(ownership.claimed?).to be_truthy
        expect(ownership.user).to eq new_owner
        expect(bike.owner_name).to eq "Sally Stuff"
      end
      context "creator is member of creation organization" do
        # PSU students keep creating accounts that use a different email from their school email, and then sending bikes to their school email
        # which means the bike isn't claimed, because it's been sent to their school account rather than their correct email account.
        # Basically, they're behaving in a way that breaks our existing email flow
        # For other bikes, e.g. POS integration bikes, we don't want to display the creator
        # If the creator is a member of the organization, we assume it was not the actual user who created the bike
        let(:user) { FactoryBot.create(:organization_member, organization: organization, name: "Stephanie Example") }
        it "is nil" do
          ownership.reload
          expect(ownership.claimed?).to be_falsey
          expect(bike.owner_name).to be_blank
          expect(bike.user).to be_blank
          ownership.user = new_owner
          ownership.mark_claimed
          bike.reload
          expect(bike.user).to eq new_owner
          expect(bike.owner_name).to eq "Sally Stuff"
        end
      end
    end
    context "b_param" do
      let(:ownership) { Ownership.new }
      let(:b_param) { BParam.new(params: { bike: { user_name: "Jane Yung" } }) }
      before do
        allow(bike).to receive(:current_ownership) { ownership }
        allow(bike).to receive(:b_params) { [b_param] }
      end
      it "returns the phone" do
        expect(bike.owner_name).to eq "Jane Yung"
      end
      context "not first ownerships" do
        it "is the users " do
          allow(ownership).to receive(:first?) { false }
          allow(bike).to receive(:current_ownership) { ownership }
          expect(bike.owner_name).to be_nil
        end
      end
    end
  end

  describe "phone" do
    let(:bike) { Bike.new }
    let(:user) { User.new(phone: "888.888.8888") }
    context "assigned phone" do
      it "returns phone" do
        bike.phone = user.phone
        expect(bike.phone).to eq "888.888.8888"
      end
    end
    context "user" do
      let(:ownership) { Ownership.new(user: user) }
      it "returns users phone" do
        allow(bike).to receive(:current_ownership) { ownership }
        expect(ownership.first?).to be_truthy
        expect(user.phone).to eq "888.888.8888"
        expect(bike.phone).to eq "888.888.8888"
      end
    end
    context "b_param" do
      let(:ownership) { Ownership.new }
      let(:b_param) { BParam.new(params: { bike: { phone: "888.888.8888" } }) }
      before do
        allow(bike).to receive(:current_ownership) { ownership }
        allow(bike).to receive(:b_params) { [b_param] }
      end
      it "returns the phone" do
        allow(bike).to receive(:first_ownership) { ownership }
        expect(bike.phone).to eq "888.888.8888"
      end
      context "not first ownerships" do
        it "is the users " do
          allow(bike).to receive(:first_ownership) { Ownership.new } # A different ownership
          expect(bike.phone).to be_nil
        end
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

  describe "cache_photo" do
    context "existing photo" do
      it "caches the photo" do
        bike = FactoryBot.create(:bike)
        FactoryBot.create(:public_image, imageable: bike)
        bike.reload
        bike.cache_photo
        expect(bike.thumb_path).not_to be_nil
      end
    end
    context "no photo" do
      it "removes existing cache if inaccurate" do
        bike = Bike.new(thumb_path: "some url")
        bike.cache_photo
        expect(bike.thumb_path).to be_nil
      end
    end
  end

  describe "components_cache_string" do
    it "caches the components" do
      bike = FactoryBot.create(:bike)
      c = FactoryBot.create(:component, bike: bike)
      bike.save
      expect(bike.components_cache_string.to_s).to match(c.ctype.name)
    end
  end

  describe "cache_stolen_attributes" do
    context "current_stolen_record with lat and long" do
      it "saves the stolen description to all description and set stolen_rec_id" do
        stolen_record = FactoryBot.create(:stolen_record, theft_description: "some theft description", latitude: 40.7143528, longitude: -74.0059731)
        bike = stolen_record.bike
        bike.description = "I love my bike"
        bike.cache_stolen_attributes
        expect(bike.all_description).to eq("I love my bike some theft description")
      end
    end
    context "no current_stolen_record" do
      it "sets the description and unsets current_stolen_record_id" do
        bike = Bike.new(current_stolen_record_id: 99999, description: "lalalala")
        bike.current_stolen_record = nil
        bike.cache_stolen_attributes

        expect(bike.current_stolen_record_id).not_to be_present
        expect(bike.all_description).to eq("lalalala")
      end
    end
  end

  describe "cache_bike" do
    let(:wheel_size) { FactoryBot.create(:wheel_size) }
    let(:bike) { FactoryBot.create(:bike, rear_wheel_size: wheel_size) }
    let!(:stolen_record) { FactoryBot.create(:stolen_record, bike: bike) }
    let(:target_cached_string) { "#{bike.mnfg_name} Sail 1999 #{bike.primary_frame_color.name} #{bike.secondary_frame_color.name} #{bike.tertiary_frame_color.name} #{bike.frame_material_name} 56foo #{bike.frame_model} #{wheel_size.name} wheel unicycle" }
    it "caches all the bike parts" do
      bike.update_attributes(year: 1999, frame_material: "steel",
                             secondary_frame_color_id: bike.primary_frame_color_id,
                             tertiary_frame_color_id: bike.primary_frame_color_id,
                             stolen: true,
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

  describe "frame_colors" do
    it "returns an array of the frame colors" do
      bike = Bike.new
      color = Color.new
      color2 = Color.new
      allow(color).to receive(:name).and_return("Blue")
      allow(color2).to receive(:name).and_return("Black")
      allow(bike).to receive(:primary_frame_color).and_return(color)
      allow(bike).to receive(:secondary_frame_color).and_return(color2)
      allow(bike).to receive(:tertiary_frame_color).and_return(color)
      expect(bike.frame_colors).to eq(%w[Blue Black Blue])
    end
  end

  describe "cgroup_array" do
    it "grabs a list of all the cgroups" do
      bike = Bike.new
      component1 = Component.new
      component2 = Component.new
      component3 = Component.new
      allow(bike).to receive(:components) { [component1, component2, component3] }
      allow(component1).to receive(:cgroup_id).and_return(1)
      allow(component2).to receive(:cgroup_id).and_return(2)
      allow(component3).to receive(:cgroup_id).and_return(2)
      expect(bike.cgroup_array).to eq([1, 2])
    end
  end

  describe "calculated_listing_order" do
    let(:bike) { Bike.new }
    it "is 1/1000 of the current timestamp" do
      expect(bike.calculated_listing_order).to eq(Time.current.to_i / 1000000)
    end

    it "is the current stolen record date stolen * 1000" do
      allow(bike).to receive(:stolen).and_return(true)
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

    context "problem date" do
      let(:problem_date) do
        digits = (Time.current.year - 1).to_s[2, 3] # last two digits of last year
        Date.strptime("#{Time.current.month}-22-00#{digits}", "%m-%d-%Y")
      end
      let(:bike) { FactoryBot.create(:stolen_bike) }
      it "does not get out of integer errors" do
        expect(bike.listing_order).to be < 1e10
        # stolen records don't actually have an after_commit hook to update
        # bikes (they probably should though). This is just checking this is
        # called correctly on save.
        bike.save
        expect(bike.listing_order).to be > (Time.current - 13.months).to_i
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
    context "suspended organization" do
      let(:organization) { FactoryBot.create(:organization, is_suspended: true) }
      it "adds an error to the bike" do
        expect(bike.validated_organization_id(organization.id)).to be_nil
        expect(bike.errors[:organizations].to_s).to match(/suspended/)
        expect(bike.errors[:organizations].to_s).to match(organization.id.to_s)
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

  describe "assignment of bike_organization_ids" do
    let(:bike) { FactoryBot.create(:bike_organized) }
    let(:organization) { bike.organizations.first }
    let(:bike_organization) { bike.bike_organizations.first }
    let(:organization_2) { FactoryBot.create(:organization) }
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
    context "invalid organization_id" do
      let(:organization_invalid) { FactoryBot.create(:organization, is_suspended: true) }
      it "adds valid organization but not invalid one" do
        bike.bike_organization_ids = [organization.id, organization_2.id, organization_invalid.id]
        expect(bike.bike_organization_ids).to eq([organization.id, organization_2.id])
      end
    end
    context "different organization" do
      it "adds organization and removes existing" do
        bike.bike_organization_ids = "#{organization_2.id}, "
        expect(bike.reload.bike_organization_ids).to eq([organization_2.id])
      end
    end
  end

  describe "handlebar_type_name" do
    let(:bike) { FactoryBot.create(:bike, handlebar_type: "bmx") }
    it "returns the normalized name" do
      normalized_name = HandlebarType.new(bike.handlebar_type).name
      expect(bike.handlebar_type_name).to eq(normalized_name)
    end
  end

  describe "cycle_type_name" do
    let(:bike) { FactoryBot.create(:bike, cycle_type: "cargo") }
    it "returns the normalized name" do
      normalized_name = CycleType.new(bike.cycle_type).name
      expect(bike.cycle_type_name).to eq(normalized_name)
    end
  end

  describe "propulsion_type_name" do
    let(:bike) { FactoryBot.create(:bike, propulsion_type: "electric-assist") }
    it "returns the normalized name" do
      normalized_name = PropulsionType.new(bike.propulsion_type).name
      expect(bike.propulsion_type_name).to eq(normalized_name)
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

  describe "#registration_location" do
    context "given a registration address with no state" do
      it "returns an empty string" do
        bike = FactoryBot.create(:bike)
        allow(bike).to receive(:registration_address).and_return({ "city": "New Paltz" })
        expect(bike.registration_location).to eq("")
      end
    end

    context "given a registration address only a state" do
      it "returns the state" do
        bike = FactoryBot.create(:bike)
        allow(bike).to receive(:registration_address).and_return({ "state": "ny" })
        expect(bike.registration_location).to eq("NY")
      end
    end

    context "given a registration address with a city and state" do
      it "returns the city and state" do
        bike = FactoryBot.create(:bike)
        allow(bike).to receive(:registration_address).and_return({ "state": "ny", city: "New York" })
        expect(bike.registration_location).to eq("New York, NY")
      end
    end
  end

  describe "#set_location_info" do
    let!(:usa) { Country.united_states }

    context "given a current_stolen_record and no bike location info" do
      let(:bike) { FactoryBot.create(:stolen_bike_in_chicago) }
      let(:stolen_record) { bike.current_stolen_record }
      it "takes location from the current stolen record" do
        bike.set_location_info

        expect(bike.to_coordinates).to eq(stolen_record.to_coordinates)
        expect(bike.city).to eq(stolen_record.city)
        expect(bike.zipcode).to eq(stolen_record.zipcode)
        expect(bike.country).to eq(stolen_record.country)
      end
      context "given a abandoned record, it instead uses the abandoned record" do
        it "takes the location from the abandoned records" do
          expect(bike.to_coordinates).to eq(stolen_record.to_coordinates)

          parking_notification = FactoryBot.create(:parking_notification, :in_los_angeles, bike: bike)
          expect(bike.current_parking_notification).to eq parking_notification
          expect(bike.to_coordinates).to eq(parking_notification.to_coordinates)

          expect(bike.city).to eq(parking_notification.city)
          expect(bike.zipcode).to eq(parking_notification.zipcode)
          expect(bike.country).to eq(parking_notification.country)
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
      end
    end

    context "given no creation org location" do
      it "takes location from the owner location" do
        city = "New York"
        zipcode = "10011"
        user = FactoryBot.create(:user_confirmed, zipcode: zipcode, country: usa, city: city)
        ownership = FactoryBot.create(:ownership, user: user, creator: user)
        bike = ownership.bike

        bike.set_location_info

        expect(bike.city).to eq(city)
        expect(bike.zipcode).to eq(zipcode)
        expect(bike.country).to eq(usa)
      end
    end

    context "given no creation org or owner location" do
      it "takes location from the geocoded request location" do
        bike = FactoryBot.build(:bike)
        geocoder_data = default_location.merge(postal_code: default_location.delete(:zipcode))
        location = double(:request_location, geocoder_data)

        bike.set_location_info(request_location: location)

        expect(bike.city).to eq(geocoder_data[:city])
        expect(bike.zipcode).to eq(geocoder_data[:postal_code])
        expect(bike.country).to eq(usa)
      end
    end
  end
end
