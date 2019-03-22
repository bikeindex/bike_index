require 'spec_helper'

describe Bike do
  it_behaves_like 'bike_searchable'
  describe 'validations' do
    it { is_expected.to belong_to :manufacturer }
    it { is_expected.to belong_to :primary_frame_color }
    it { is_expected.to belong_to :secondary_frame_color }
    it { is_expected.to belong_to :tertiary_frame_color }
    it { is_expected.to belong_to :rear_wheel_size }
    it { is_expected.to belong_to :front_wheel_size }
    it { is_expected.to belong_to :rear_gear_type }
    it { is_expected.to belong_to :front_gear_type }
    it { is_expected.to belong_to :paint }
    it { is_expected.to belong_to :updator }
    it { is_expected.to have_many :bike_organizations }
    it { is_expected.to have_many(:organizations).through(:bike_organizations) }
    it { is_expected.to have_one :creation_state }
    it { is_expected.to delegate_method(:creation_description).to(:creation_state) }
    it { is_expected.to belong_to :creation_organization }
    # it { is_expected.to delegate_method(:creator).to(:creation_state) }
    # it { is_expected.to have_one(:creation_organization).through(:creation_state) }
    it { is_expected.to belong_to :current_stolen_record }
    it { is_expected.to have_many :duplicate_bike_groups }
    it { is_expected.to have_many :b_params }
    it { is_expected.to have_many :stolen_notifications }
    it { is_expected.to have_many :stolen_records }
    it { is_expected.to have_many :ownerships }
    it { is_expected.to have_many :public_images }
    it { is_expected.to have_many :components }
    it { is_expected.to have_many :other_listings }
    it { is_expected.to accept_nested_attributes_for :stolen_records }
    it { is_expected.to accept_nested_attributes_for :components }
    # it { is_expected.to validate_presence_of :creation_state_id }
    it { is_expected.to validate_presence_of :creator }
    it { is_expected.to validate_presence_of :propulsion_type }
    it { is_expected.to validate_presence_of :serial_number }
    it { is_expected.to validate_presence_of :manufacturer_id }
    it { is_expected.to validate_presence_of :primary_frame_color_id }
  end

  describe 'scopes' do
    it 'default scopes to created_at desc' do
      expect(Bike.all.to_sql).to eq(Bike.unscoped.where(example: false, hidden: false).order('listing_order desc').to_sql)
    end
    it 'scopes to only stolen bikes' do
      expect(Bike.stolen.to_sql).to eq(Bike.where(stolen: true).to_sql)
    end
    it 'non_stolen scopes to only non_stolen bikes' do
      expect(Bike.non_stolen.to_sql).to eq(Bike.where(stolen: false).to_sql)
    end
    it 'non_recovered scopes to only non_recovered bikes' do
      expect(Bike.non_recovered.to_sql).to eq(Bike.where(recovered: false).to_sql)
    end
  end

  describe 'recovered_records' do
    it 'default scopes to created_at desc' do
      bike = FactoryBot.create(:bike)
      expect(bike.recovered_records.to_sql).to eq(StolenRecord.unscoped.where(bike_id: bike.id, current: false).order('date_recovered desc').to_sql)
    end
  end

  describe 'visible_by' do
    it "isn't be visible to owner unless user hidden" do
      bike = Bike.new(hidden: true)
      user = User.new
      allow(bike).to receive(:owner).and_return(user)
      allow(bike).to receive(:user_hidden).and_return(false)
      expect(bike.visible_by(user)).to be_falsey
    end
    it 'is visible to owner' do
      bike = Bike.new(hidden: true)
      user = User.new
      allow(bike).to receive(:owner).and_return(user)
      allow(bike).to receive(:user_hidden).and_return(true)
      expect(bike.visible_by(user)).to be_truthy
    end
    it 'is visible to superuser' do
      bike = Bike.new(hidden: true)
      user = User.new
      user.superuser = true
      expect(bike.visible_by(user)).to be_truthy
    end
    it 'is visible if not hidden' do
      bike = Bike.new
      expect(bike.visible_by).to be_truthy
    end
  end

  describe 'owner' do
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

  describe 'frame_size' do
    it 'removes crap from bike size strings' do
      bike = Bike.new(frame_size: '19\\\\"')
      bike.clean_frame_size
      expect(bike.frame_size_number).to eq(19)
      expect(bike.frame_size).to eq('19in')
      expect(bike.frame_size_unit).to eq('in')
    end
    it 'sets things' do
      bike = Bike.new(frame_size_number: '19.5sa', frame_size_unit: 'in')
      bike.clean_frame_size
      expect(bike.frame_size_number).to eq(19.5)
      expect(bike.frame_size).to eq('19.5in')
      expect(bike.frame_size_unit).to eq('in')
    end
    it 'removes extra numbers and other things from size strings' do
      bike = Bike.new(frame_size: '19.5 somethingelse medium 54cm')
      bike.clean_frame_size
      expect(bike.frame_size_number).to eq(19.5)
      expect(bike.frame_size).to eq('19.5in')
      expect(bike.frame_size_unit).to eq('in')
    end
    it "figures out that it's cm" do
      bike = Bike.new(frame_size: 'Med/54cm')
      bike.clean_frame_size
      expect(bike.frame_size_number).to eq(54)
      expect(bike.frame_size).to eq('54cm')
      expect(bike.frame_size_unit).to eq('cm')
    end
    it 'is cool with ordinal sizing' do
      bike = Bike.new(frame_size: 'Med')
      bike.clean_frame_size
      expect(bike.frame_size).to eq('m')
      expect(bike.frame_size_unit).to eq('ordinal')
    end
    it 'is cool with ordinal sizing' do
      bike = Bike.new(frame_size: 'M')
      bike.clean_frame_size
      expect(bike.frame_size).to eq('m')
      expect(bike.frame_size_unit).to eq('ordinal')
    end

    it 'has before_save_callback_method defined for clean_frame_size' do
      expect(Bike._save_callbacks.select { |cb| cb.kind.eql?(:before) }
        .map(&:raw_filter).include?(:clean_frame_size)).to eq(true)
    end
  end

  describe 'user?' do
    let(:bike) { Bike.new }
    let(:ownership) { Ownership.new }
    before { allow(bike).to receive(:current_ownership) { ownership } }
    it "returns false if ownership isn't claimed" do
      expect(bike.user?).to be_falsey
    end
    context "claimed" do
      let(:user) { User.new }
      let(:ownership) { Ownership.new(claimed: true, user: user) }
      it 'returns true if ownership is claimed' do
        expect(bike.user?).to be_truthy
      end
    end
  end

  describe 'can_be_claimed_by' do
    context 'already claimed' do
      it 'returns false' do
        user = User.new
        bike = Bike.new
        allow(bike).to receive(:user?).and_return(true)
        expect(bike.can_be_claimed_by(user)).to be_falsey
      end
    end
    context 'can be claimed' do
      it 'returns true' do
        user = User.new
        ownership = Ownership.new
        bike = Bike.new
        allow(bike).to receive(:current_ownership).and_return(ownership)
        allow(ownership).to receive(:user).and_return(user)
        allow(bike).to receive(:user?).and_return(false)
        expect(bike.can_be_claimed_by(user)).to be_truthy
      end
    end
    context 'no current_ownership' do # AKA Something is broken. Bikes should always have ownerships
      it 'does not explode' do
        user = User.new
        bike = Bike.new
        expect(bike.can_be_claimed_by(user)).to be_falsey
      end
    end
  end

  describe 'cleaned_error_messages' do
    let(:errors) { ["Manufacturer can't be blank", "Bike can't be blank", "Association error Ownership wasn't saved. Are you sure the bike was created?"] }
    it "removes error messages we don't want to show users" do
      bike = Bike.new
      errors.each { |e| bike.errors.add(:base, e) }
      expect(bike.cleaned_error_messages.length).to eq(1)
    end
  end

  describe "authorize_bike_for_user(!)" do
    let(:bike) { ownership.bike }
    let(:creator) { ownership.creator }
    let(:user) { FactoryBot.create(:user) }
    let(:bike) { ownership.bike }

    context "un-organized" do
      let(:ownership) { FactoryBot.create(:ownership) }
      context "no user" do
        it "returns false" do
          expect(bike.authorize_bike_for_user(nil)).to be_falsey
          expect(bike.authorize_bike_for_user!(nil)).to be_falsey
        end
      end
      context "unauthorized" do
        it "returns false" do
          expect(bike.authorize_bike_for_user(user)).to be_falsey
          expect(bike.authorize_bike_for_user!(user)).to be_falsey
        end
      end
      context "creator" do
        it "returns true" do
          expect(bike.authorize_bike_for_user(creator)).to be_truthy
          expect(bike.authorize_bike_for_user!(creator)).to be_truthy
        end
      end
      context "claimed" do
        let(:ownership) { FactoryBot.create(:ownership_claimed) }
        let(:user) { ownership.user }
        it "returns true for user, not creator" do
          expect(bike.claimed?).to be_truthy
          expect(bike.authorize_bike_for_user(creator)).to be_falsey
          expect(bike.authorize_bike_for_user(user)).to be_truthy
          expect(bike.authorize_bike_for_user!(creator)).to be_falsey
          expect(bike.authorize_bike_for_user!(user)).to be_truthy
        end
      end
      context "can_be_claimed_by" do
        let(:ownership) { FactoryBot.create(:ownership, user: user) }
        it "marks claimed and returns true" do
          expect(ownership.claimed?).to be_falsey
          expect(bike.claimed?).to be_falsey
          expect(ownership.owner).to eq creator
          expect(bike.authorize_bike_for_user!(creator)).to be_truthy
          expect(bike.authorize_bike_for_user(user)).to be_truthy
          expect(bike.authorize_bike_for_user!(user)).to be_truthy
          expect(bike.claimed?).to be_truthy
          expect(bike.authorize_bike_for_user!(creator)).to be_falsey
          ownership.reload
          expect(ownership.owner).to eq user
          expect(bike.ownerships.count).to eq 1
        end
      end
    end
    context "creation organization" do
      let(:ownership) { FactoryBot.create(:ownership_organization_bike) }
      let(:organization) { bike.creation_organization }
      let(:member) { FactoryBot.create(:organization_member, organization: organization) }
      before { expect(bike.creation_organization).to eq member.organizations.first }
      context "unclaimed" do
        context "member of organization" do
          it "returns true" do
            expect(bike.claimed?).to be_falsey
            expect(bike.authorize_bike_for_user!(member)).to be_truthy
            expect(bike.authorize_bike_for_user!(member)).to be_truthy
            expect(bike.claimed?).to be_falsey
          end
        end
        context "non-member" do
          it "returns false" do
            expect(bike.authorize_bike_for_user(user)).to be_falsey
            expect(bike.authorize_bike_for_user!(user)).to be_falsey
          end
        end
      end
      context "claimed" do
        let(:ownership) { FactoryBot.create(:ownership_organization_bike, user: user, claimed: true) }
        it "returns false" do
          expect(bike.claimed?).to be_truthy
          expect(bike.owner).to eq user
          expect(bike.authorize_bike_for_user(member)).to be_falsey
          expect(bike.claimed?).to be_truthy
        end
      end
      context "more than one ownership" do
        let!(:ownership_2) { FactoryBot.create(:ownership_organization_bike, bike: bike, creator: user) }
        it "returns false" do
          bike.reload
          expect(bike.owner).to eq user
          expect(bike.authorize_bike_for_user(member)).to be_falsey
          expect(bike.authorize_bike_for_user!(member)).to be_falsey
        end
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
    context "with owner with notification_unstolen false" do
      it "is falsey" do
        allow(bike).to receive(:owner) { User.new(notification_unstolen: false) }
        expect(bike.contact_owner?).to be_falsey
        expect(bike.contact_owner?(User.new)).to be_falsey
        expect(bike.contact_owner?(admin)).to be_falsey
        expect(bike.display_contact_owner?(admin)).to be_falsey
      end
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
  end

  describe 'user_hidden' do
    it 'is true if bike is hidden and ownership is user hidden' do
      bike = Bike.new(hidden: true)
      ownership = Ownership.new(user_hidden: true)
      allow(bike).to receive(:current_ownership).and_return(ownership)
      expect(bike.user_hidden).to be_truthy
    end
    it 'is false otherwise' do
      bike = Bike.new(hidden: true)
      expect(bike.user_hidden).to be_falsey
    end
  end

  describe 'fake_deleted' do
    it 'is true if bike is hidden and ownership is user hidden' do
      bike = Bike.new(hidden: true)
      ownership = Ownership.new(user_hidden: true)
      allow(bike).to receive(:current_ownership).and_return(ownership)
      expect(bike.fake_deleted).to be_falsey
    end
    it 'is false otherwise' do
      bike = Bike.new(hidden: true)
      expect(bike.fake_deleted).to be_truthy
    end
  end

  describe 'set_user_hidden' do
    it 'unmarks user hidden, saves ownership and marks self unhidden' do
      ownership = FactoryBot.create(:ownership, user_hidden: true)
      bike = ownership.bike
      bike.hidden = true
      bike.marked_user_unhidden = true
      bike.set_user_hidden
      expect(bike.hidden).to be_falsey
      expect(ownership.reload.user_hidden).to be_falsey
    end

    it 'marks updates ownership user hidden, marks self hidden' do
      ownership = FactoryBot.create(:ownership)
      bike = ownership.bike
      bike.marked_user_hidden = true
      bike.set_user_hidden
      expect(bike.hidden).to be_truthy
      expect(ownership.reload.user_hidden).to be_truthy
    end

    it 'has before_save_callback_method defined for set_user_hidden' do
      expect(Bike._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_user_hidden)).to eq(true)
    end
  end

  describe 'find_current_stolen_record' do
    it 'returns the last current stolen record if bike is stolen' do
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

  describe 'set_mnfg_name' do
    it 'returns the value of manufacturer_other if manufacturer is other' do
      bike = Bike.new
      other_manufacturer = Manufacturer.new
      allow(other_manufacturer).to receive(:name).and_return('Other')
      allow(bike).to receive(:manufacturer).and_return(other_manufacturer)
      allow(bike).to receive(:manufacturer_other).and_return('Other manufacturer name')
      bike.set_mnfg_name
      expect(bike.mnfg_name).to eq('Other manufacturer name')
    end

    it "returns the name of the manufacturer if it isn't other" do
      bike = Bike.new
      manufacturer = Manufacturer.new
      allow(manufacturer).to receive(:name).and_return('Mnfg name')
      allow(bike).to receive(:manufacturer).and_return(manufacturer)
      bike.set_mnfg_name
      expect(bike.mnfg_name).to eq('Mnfg name')
    end

    it 'returns Just SE Bikes' do
      bike = Bike.new
      manufacturer = Manufacturer.new
      allow(manufacturer).to receive(:name).and_return('SE Racing (S E Bikes)')
      allow(bike).to receive(:manufacturer).and_return(manufacturer)
      bike.set_mnfg_name
      expect(bike.mnfg_name).to eq('SE Racing')
    end
  end

  describe 'type' do
    it 'returns the cycle type name' do
      bike = FactoryBot.create(:bike, cycle_type: "trailer")
      expect(bike.type).to eq(bike.cycle_type_name.downcase)
    end
  end

  describe 'video_embed_src' do
    it 'returns false if there is no video_embed' do
      @bike = Bike.new
      allow(@bike).to receive(:video_embed).and_return(nil)
      expect(@bike.video_embed_src).to be_nil
    end

    it 'returns just the url of the video from a youtube iframe' do
      youtube_share = '
          <iframe width="560" height="315" src="//www.youtube.com/embed/Sv3xVOs7_No" frameborder="0" allowfullscreen></iframe>
        '
      @bike = Bike.new
      allow(@bike).to receive(:video_embed).and_return(youtube_share)
      expect(@bike.video_embed_src).to eq('//www.youtube.com/embed/Sv3xVOs7_No')
    end

    it 'returns just the url of the video from a vimeo iframe' do
      vimeo_share = '<iframe src="http://player.vimeo.com/video/13094257" width="500" height="281" frameborder="0" webkitAllowFullScreen mozallowfullscreen allowFullScreen></iframe><p><a href="http://vimeo.com/13094257">Fixed Gear Kuala Lumpur, RatsKL Putrajaya</a> from <a href="http://vimeo.com/user3635109">irmanhilmi</a> on <a href="http://vimeo.com">Vimeo</a>.</p>'
      @bike = Bike.new
      allow(@bike).to receive(:video_embed).and_return(vimeo_share)
      expect(@bike.video_embed_src).to eq('http://player.vimeo.com/video/13094257')
    end
  end

  describe 'set_mnfg_name' do
    it 'sets a bikes mnfg_name' do
      manufacturer = FactoryBot.create(:manufacturer, name: 'SE Racing ( S E Bikes )')
      bike = Bike.new
      allow(bike).to receive(:manufacturer).and_return(manufacturer)
      bike.set_mnfg_name
      expect(bike.mnfg_name).to eq('SE Racing')
    end
    it 'sets a bikes mnfg_name' do
      manufacturer = FactoryBot.create(:manufacturer, name: 'Other')
      bike = Bike.new(manufacturer_other: '<a href="bad_site.js">stuff</a>')
      allow(bike).to receive(:manufacturer).and_return(manufacturer)
      bike.set_mnfg_name
      expect(bike.mnfg_name).to eq("stuff")
    end
    it 'has before_save_callback_method defined for set_mnfg_name' do
      expect(Bike._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_mnfg_name)).to eq(true)
    end
  end

  describe 'set_normalized_attributes' do
    it 'sets a bikes normalized_serial and switches unknown to absent' do
      bike = Bike.new(serial_number: ' UNKNOWn ')
      expect_any_instance_of(SerialNormalizer).to receive(:normalized).and_return('normal')
      bike.normalize_attributes
      expect(bike.serial_number).to eq('absent')
      expect(bike.serial_normalized).to eq('normal')
    end
    it 'sets normalized owner email' do
      bike = Bike.new(owner_email: '  somethinG@foo.orG')
      bike.normalize_attributes
      expect(bike.owner_email).to eq('something@foo.org')
    end
    it 'has before_save_callback_method defined' do
      expect(Bike._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:normalize_attributes)).to eq(true)
    end

    context 'confirmed secondary email' do
      it 'sets email to the primary email' do
        user_email = FactoryBot.create(:user_email)
        user = user_email.user
        bike = FactoryBot.build(:bike, owner_email: user_email.email)
        expect(user.email).to_not eq user_email.email
        expect(bike.owner_email).to eq user_email.email
        bike.normalize_attributes
        expect(bike.owner_email).to eq user.email
      end
    end

    context 'unconfirmed secondary email' do
      it 'sets owner email to primary email' do
        user_email = FactoryBot.create(:user_email, confirmation_token: '123456789')
        user = user_email.user
        expect(user_email.unconfirmed).to be_truthy
        expect(user.email).to_not eq user_email.email
        bike = FactoryBot.build(:bike, owner_email: user_email.email)
        expect(bike.owner_email).to eq user_email.email
        bike.normalize_attributes
        expect(bike.owner_email).to eq user_email.email
      end
    end
  end

  describe 'serial' do
    it 'only returns the serial if we should show people the serial' do
      # We're hiding serial numbers for bikes that are recovered to provide a method of verifying
      # ownership
      bike = Bike.new
      allow(bike).to receive(:serial_number).and_return('something')
      allow(bike).to receive(:recovered).and_return(true)
      expect(bike.serial).to be_nil
    end
  end

  describe 'pg search' do
    it 'returns a bike which has a matching part of its description' do
      @bike = FactoryBot.create(:bike, description: 'Phil wood hub')
      @bikes = Bike.text_search('phil wood hub')
      expect(@bikes).to include(@bike)
    end

    it 'returns the bikes in the default scope pattern if there is no query' do
      bike = FactoryBot.create(:bike, description: 'Phil wood hub')
      FactoryBot.create(:bike)
      bikes = Bike.text_search('')
      expect(bikes.first).to eq(bike)
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
          expect_any_instance_of(Geohelper).to_not receive(:formatted_address_hash)
          expect(bike.registration_address).to eq target.as_json
        end
      end
    end
  end

  describe "user_name" do
    let(:bike) { Bike.new }
    let(:user) { User.new(name: "Fun McGee") }
    context "user" do
      let(:ownership) { Ownership.new(user: user) }
      it "returns users name" do
        allow(bike).to receive(:current_ownership) { ownership }
        expect(ownership.first?).to be_truthy
        expect(bike.user_name).to eq "Fun McGee"
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
        expect(bike.user_name).to eq "Jane Yung"
      end
      context "not first ownerships" do
        it "is the users " do
          allow(ownership).to receive(:first?) { false }
          allow(bike).to receive(:current_ownership) { ownership }
          expect(bike.user_name).to be_nil
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

  describe 'set_paints' do
    it 'returns true if paint is a color' do
      FactoryBot.create(:color, name: 'Bluety')
      bike = Bike.new
      allow(bike).to receive(:paint_name).and_return(' blueTy')
      expect { bike.set_paints }.not_to change(Paint, :count)
      expect(bike.paint).to be_nil
    end
    it 'removes paint id if paint_name is nil' do
      paint = FactoryBot.create(:paint)
      bike = Bike.new(paint_id: paint.id)
      bike.paint_name = ''
      bike.set_paints
      expect(bike.paint).to be_nil
    end
    it 'sets the paint if it exists' do
      FactoryBot.create(:paint, name: 'poopy pile')
      bike = Bike.new
      allow(bike).to receive(:paint_name).and_return('Poopy PILE  ')
      expect { bike.set_paints }.not_to change(Paint, :count)
      expect(bike.paint.name).to eq('poopy pile')
    end
    it 'creates a new paint and set it otherwise' do
      bike = Bike.new
      bike.paint_name = ['Food Time SOOON']
      expect { bike.set_paints }.to change(Paint, :count).by(1)
      expect(bike.paint.name).to eq('food time sooon')
    end
    it 'has before_save_callback_method defined as a before_save callback' do
      expect(Bike._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_paints)).to eq(true)
    end
  end

  describe 'cache_photo' do
    context 'existing photo' do
      it 'caches the photo' do
        bike = FactoryBot.create(:bike)
        FactoryBot.create(:public_image, imageable: bike)
        bike.reload
        bike.cache_photo
        expect(bike.thumb_path).not_to be_nil
      end
    end
    context 'no photo' do
      it 'removes existing cache if inaccurate' do
        bike = Bike.new(thumb_path: 'some url')
        bike.cache_photo
        expect(bike.thumb_path).to be_nil
      end
    end
  end

  describe 'components_cache_string' do
    it 'caches the components' do
      bike = FactoryBot.create(:bike)
      c = FactoryBot.create(:component, bike: bike)
      bike.save
      expect(bike.components_cache_string.to_s).to match(c.ctype.name)
    end
  end

  describe 'cache_stolen_attributes' do
    context 'current_stolen_record with lat and long' do
      it 'saves the stolen description to all description and set stolen_rec_id' do
        stolen_record = FactoryBot.create(:stolen_record, theft_description: 'some theft description', latitude: 40.7143528, longitude: -74.0059731)
        bike = stolen_record.bike
        bike.description = 'I love my bike'
        bike.cache_stolen_attributes
        expect(bike.all_description).to eq('I love my bike some theft description')
        expect(bike.stolen_lat).to eq(40.7143528)
        expect(bike.stolen_long).to eq(-74.0059731)
      end
    end
    context 'no current_stolen_record' do
      it 'grabs the desc and erase current_stolen_id' do
        bike = Bike.new(current_stolen_record_id: 69, description: 'lalalala', stolen_lat: 40.7143528, stolen_long: -74.0059731)
        bike.cache_stolen_attributes
        expect(bike.current_stolen_record_id).not_to be_present
        expect(bike.all_description).to eq('lalalala')
        expect(bike.stolen_lat).to eq nil
        expect(bike.stolen_long).to eq nil
      end
    end
  end

  describe 'cache_bike' do
    it 'calls cache photo and cache component and erase stolen_rec_id' do
      bike = FactoryBot.create(:bike, current_stolen_record_id: 69)
      expect(bike).to receive(:cache_photo)
      expect(bike).to receive(:cache_stolen_attributes)
      expect(bike).to receive(:components_cache_string)
      bike.cache_bike
      expect(bike.current_stolen_record_id).to be_nil
    end
    it 'caches all the bike parts' do
      wheel_size = FactoryBot.create(:wheel_size)
      bike = FactoryBot.create(:bike, rear_wheel_size: wheel_size)
      stolen_record = FactoryBot.create(:stolen_record, bike: bike)
      bike.update_attributes(year: 1999, frame_material: "steel",
                             secondary_frame_color_id: bike.primary_frame_color_id,
                             tertiary_frame_color_id: bike.primary_frame_color_id,
                             stolen: true,
                             handlebar_type: "bmx",
                             propulsion_type: "sail",
                             cycle_type: "unicycle",
                             frame_size: '56', frame_size_unit: 'foo',
                             frame_model: 'Some model')
      bike.cache_bike
      expect(bike.cached_data).to eq("#{bike.mnfg_name} Sail 1999 #{bike.primary_frame_color.name} #{bike.secondary_frame_color.name} #{bike.tertiary_frame_color.name} #{bike.frame_material_name} 56foo #{bike.frame_model} #{wheel_size.name} wheel unicycle")
      expect(bike.current_stolen_record_id).to eq(stolen_record.id)
    end
    it 'has before_save_callback_method defined as a before_save callback' do
      expect(Bike._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:cache_bike)).to eq(true)
    end
  end

  describe 'frame_colors' do
    it 'returns an array of the frame colors' do
      bike = Bike.new
      color = Color.new
      color2 = Color.new
      allow(color).to receive(:name).and_return('Blue')
      allow(color2).to receive(:name).and_return('Black')
      allow(bike).to receive(:primary_frame_color).and_return(color)
      allow(bike).to receive(:secondary_frame_color).and_return(color2)
      allow(bike).to receive(:tertiary_frame_color).and_return(color)
      expect(bike.frame_colors).to eq(%w[Blue Black Blue])
    end
  end

  describe 'cgroup_array' do
    it 'grabs a list of all the cgroups' do
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

  describe 'get_listing_order' do
    it 'is 1/1000 of the current timestamp' do
      bike = Bike.new
      time = Time.now
      allow(bike).to receive(:updated_at).and_return(time)
      lo = bike.get_listing_order
      expect(lo).to eq(time.to_time.to_i / 1000000)
    end

    it 'is the current stolen record date stolen * 1000' do
      bike = Bike.new
      allow(bike).to receive(:stolen).and_return(true)
      stolen_record = StolenRecord.new
      yesterday = Time.now - 1.days
      allow(stolen_record).to receive(:date_stolen).and_return(yesterday)
      allow(bike).to receive(:current_stolen_record).and_return(stolen_record)
      lo = bike.get_listing_order
      expect(lo).to eq(yesterday.to_time.to_i)
    end

    it 'is the updated_at' do
      bike = Bike.new
      last_week = Time.now - 7.days
      allow(bike).to receive(:updated_at).and_return(last_week)
      allow(bike).to receive(:stock_photo_url).and_return('https://some_photo.cum')
      lo = bike.get_listing_order
      expect(lo).to eq(last_week.to_time.to_i / 10000)
    end

    it 'does not get out of integer errors' do
      stolen_record = FactoryBot.create(:stolen_record)
      bike = stolen_record.bike
      digits = (Time.now.year - 1).to_s[2, 3] # last two digits of last year
      problem_date = Date.strptime("#{Time.now.month}-22-00#{digits}", "%m-%d-%Y")
      bike.update_attribute :stolen, true
      stolen_record.update_attribute :date_stolen, problem_date
      bike.update_attribute :listing_order, bike.get_listing_order
      expect(bike.listing_order).to be > (Time.now - 13.months).to_time.to_i
    end
  end

  describe 'title_string' do
    it 'escapes correctly' do
      bike = Bike.new(frame_model: '</title><svg/onload=alert(document.cookie)>')
      allow(bike).to receive(:mnfg_name).and_return('baller')
      allow(bike).to receive(:type).and_return('bike')
      expect(bike.title_string).not_to match('</title><svg/onload=alert(document.cookie)>')
      expect(bike.title_string.length).to be > 5
    end
  end

  describe 'validated_organization_id' do
    let(:bike) { Bike.new }
    context 'valid organization' do
      let(:organization) { FactoryBot.create(:organization) }
      context 'slug' do
        it 'returns true' do
          expect(bike.validated_organization_id(organization.slug)).to eq organization.id
        end
      end
      context 'id' do
        it 'returns true' do
          expect(bike.validated_organization_id(organization.id)).to eq organization.id
        end
      end
    end
    context 'suspended organization' do
      let(:organization) { FactoryBot.create(:organization, is_suspended: true) }
      it 'adds an error to the bike' do
        expect(bike.validated_organization_id(organization.id)).to be_nil
      end
    end
    context 'unable to find organization' do
      it 'adds an error to the bike' do
        expect(bike.validated_organization_id('some org')).to be_nil
        expect(bike.errors[:organization].to_s).to match(/not found/)
        expect(bike.errors[:organization].to_s).to match(/some org/)
      end
    end
  end

  describe 'assignment of bike_organization_ids' do
    let(:bike) { FactoryBot.create(:organization_bike) }
    let(:organization) { bike.organizations.first }
    let(:bike_organization) { bike.bike_organizations.first }
    let(:organization_2) { FactoryBot.create(:organization) }
    before { expect(bike.bike_organization_ids).to eq([organization.id]) }
    context 'no organization_ids' do
      it 'removes bike organizations' do
        expect(bike.bike_organization_ids).to eq([organization.id])
        bike.bike_organization_ids = ''
        # Acts as paranoid
        bike_organization.reload
        expect(bike_organization.deleted_at).to be_within(1.second).of Time.now
        expect(bike.bike_organization_ids).to eq([])
        bike.bike_organization_ids = [organization.id]
        bike.reload
        expect(bike.bike_organization_ids).to eq([organization.id]) # despite uniqueness validation
      end
    end
    context 'invalid organization_id' do
      let(:organization_invalid) { FactoryBot.create(:organization, is_suspended: true) }
      it 'adds valid organization but not invalid one' do
        bike.bike_organization_ids = [organization.id, organization_2.id, organization_invalid.id]
        expect(bike.bike_organization_ids).to eq([organization.id, organization_2.id])
      end
    end
    context 'different organization' do
      it 'adds organization and removes existing' do
        bike.bike_organization_ids = "#{organization_2.id}, "
        expect(bike.bike_organization_ids).to eq([organization_2.id])
      end
    end
  end

  describe 'handlebar_type_name' do
    let(:bike) { FactoryBot.create(:bike, handlebar_type: "bmx") }
    it "returns the normalized name" do
      normalized_name = HandlebarType.new(bike.handlebar_type).name
      expect(bike.handlebar_type_name).to eq(normalized_name)
    end
  end

  describe 'cycle_type_name' do
    let(:bike) { FactoryBot.create(:bike, cycle_type: "cargo") }
    it "returns the normalized name" do
      normalized_name = CycleType.new(bike.cycle_type).name
      expect(bike.cycle_type_name).to eq(normalized_name)
    end
  end

  describe 'propulsion_type_name' do
    let(:bike) { FactoryBot.create(:bike, propulsion_type: "electric-assist") }
    it "returns the normalized name" do
      normalized_name = PropulsionType.new(bike.propulsion_type).name
      expect(bike.propulsion_type_name).to eq(normalized_name)
    end
  end
end
