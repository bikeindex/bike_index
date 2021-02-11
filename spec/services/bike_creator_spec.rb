require "rails_helper"

RSpec.describe BikeCreator do
  let(:subject) { BikeCreator }
  let(:b_param) { BParam.new }
  let(:instance) { subject.new(b_param) }

  context "legacy BikeCreatorBuilder methods" do
    describe "building" do
      it "returns a new bike object from the params with the b_param_id" do
        allow(b_param).to receive(:id).and_return(9)
        allow(b_param).to receive(:creator_id).and_return(6)
        allow(b_param).to receive(:params).and_return({bike: {serial_number: "AAAA"}}.as_json)
        bike = instance.build_bike
        expect(bike.serial_number).to eq("AAAA")
        expect(bike.updator_id).to eq(6)
        expect(bike.b_param_id).to eq(9)
      end
    end

    describe "add_front_wheel_size" do
      it "sets the front wheel equal to the rear wheel if it's present" do
        bike = Bike.new
        allow(bike).to receive(:rear_wheel_size_id).and_return(1)
        allow(bike).to receive(:rear_tire_narrow).and_return(true)
        instance.send(:add_front_wheel_size, bike)
        expect(bike.front_wheel_size_id).to eq(1)
        expect(bike.rear_tire_narrow).to be_truthy
      end
    end

    describe "add_required_attributes" do
      it "calls the methods it needs to call" do
        bike = Bike.new
        instance.send(:add_required_attributes, bike)
        expect(bike.cycle_type).to eq("bike")
        expect(bike.propulsion_type).to eq("foot-pedal")
      end
    end

    describe "find_or_build_bike" do
      it "calls verified bike on new bike and return the bike" do
        bike = Bike.new
        expect(instance).to receive(:build_bike).and_return(bike)
        allow(instance).to receive(:add_required_attributes).and_return(bike)
        expect(instance.send(:find_or_build_bike)).to eq(bike)
      end
    end

    describe "build" do
      it "returns the b_param bike if one exists" do
        bike = Bike.new
        # allow(b_param).to receive(:bike).and_return(bike)
        allow(b_param).to receive(:created_bike).and_return(bike)
        expect(instance.send(:find_or_build_bike)).to eq(bike)
      end
    end
  end

  describe "include_bike_book" do
    it "returns the bike if stuff isn't present" do
      expect(instance.send(:add_bike_book_data)).to be_nil
    end
    context "se data" do
      it "adds se bike data if it exists" do
        manufacturer = FactoryBot.create(:manufacturer, name: "SE Bikes")
        color = FactoryBot.create(:color)
        bike = {
          serial_number: "Some serial",
          description: "Input description",
          manufacturer_id: manufacturer.id,
          year: 2014,
          frame_model: "Draft",
          primary_frame_color_id: color.id
        }
        b_param = FactoryBot.create(:b_param, params: {bike: bike})
        BikeCreator.new(b_param).send(:add_bike_book_data)

        b_param.reload
        expect(b_param.params["components"].count).to be > 5
        expect(b_param.params["components"].count { |c| c["is_stock"] }).to be > 5
        expect(b_param.params["components"].count { |c| !c["is_stock"] }).to eq(0)
        expect(b_param.bike["description"]).not_to eq("Input description")
        expect(b_param.bike["serial_number"]).to eq("Some serial")
        expect(b_param.bike["primary_frame_color_id"]).to eq(color.id)
      end
    end
  end

  describe "clear_bike" do
    it "removes the existing bike and transfer the errors to a new active record object" do
      b_param = BParam.new
      bike = FactoryBot.create(:bike)
      bike.errors.add(:rando_error, "LOLZ")
      creator = BikeCreator.new(b_param).send(:clear_bike, bike)
      expect(creator.errors.messages[:rando_error]).not_to be_nil
      expect(Bike.where(id: bike.id)).to be_empty
    end
  end

  describe "validate_record" do
    it "calls remove associations if the bike was created and there are errors" do
      bike = Bike.new
      allow(b_param).to receive(:bike).and_return(bike)
      allow(bike).to receive(:errors).and_return(messages: "some errors")
      expect(instance).to receive(:clear_bike).and_return(bike)
      instance.send(:validate_record, bike)
    end

    it "calls delete the already existing bike if one exists" do
      # This is to clean up duplicates, people press the 'add bike button' many times when its slow to respond
      bike = FactoryBot.create(:bike)
      bike1 = Bike.new
      allow(b_param).to receive(:created_bike).and_return(bike1)
      expect(instance.send(:validate_record, bike)).to eq(bike1)
      expect(Bike.where(id: bike1.id)).to be_empty
    end

    it "associates the b_param with the bike and clear the bike_errors if the bike is created" do
      bike = Bike.new
      allow(b_param).to receive(:id).and_return(42)
      allow(bike).to receive(:id).and_return(69)
      allow(bike).to receive(:errors).and_return(nil)
      expect(b_param).to receive(:update_attributes).with(created_bike_id: 69, bike_errors: nil)
      instance.send(:validate_record, bike)
    end

    describe "no_duplicate" do
      let(:existing_bike) { FactoryBot.create(:bike, serial_number: "some serial number", owner_email: email) }
      let(:new_bike) { FactoryBot.create(:bike, serial_number: "some serial number", owner_email: new_email) }
      let!(:ownerships) do
        [FactoryBot.create(:ownership, bike: existing_bike, owner_email: email),
          FactoryBot.create(:ownership, bike: new_bike, owner_email: new_email)]
      end
      let(:params) do
        {
          bike: {
            serial_number: "some serial number",
            owner_email: new_email,
            no_duplicate: true
          }
        }
      end
      let(:b_param) { FactoryBot.create(:b_param, creator: existing_bike.current_ownership.creator, params: params) }
      context "same email" do
        let(:email) { "something@gmail.com" }
        let(:new_email) { "Something@GMAIL.com" }
        it "finds a duplicate" do
          expect(b_param.no_duplicate?).to be_truthy
          expect(b_param.find_duplicate_bike(new_bike)).to be_truthy
          expect {
            instance.send(:validate_record, new_bike)
          }.to change(Ownership, :count).by(-1)
          b_param.reload
          expect(b_param.created_bike_id).to eq existing_bike.id
          expect(Bike.where(id: new_bike.id)).to_not be_present
        end
      end
      context "different email" do
        let(:email) { "something@gmail.com" }
        let(:new_email) { "newsomething@gmail.com" }
        it "does not find a non-duplicate" do
          expect(b_param.no_duplicate?).to be_truthy
          expect(b_param.find_duplicate_bike(new_bike)).to be_falsey
          expect {
            instance.send(:validate_record, new_bike)
          }.to change(Ownership, :count).by 0
          b_param.reload
          expect(b_param.created_bike_id).to eq new_bike.id
        end
      end
    end
  end

  describe "save_bike" do
    let(:b_param) { BParam.new(origin: "api_v1") }
    it "creates a bike with the parameters it is passed and returns it" do
      Sidekiq::Testing.inline! do
        organization = FactoryBot.create(:organization)
        user = FactoryBot.create(:user)
        manufacturer = FactoryBot.create(:manufacturer)
        color = FactoryBot.create(:color)
        wheel_size = FactoryBot.create(:wheel_size)
        bike = Bike.new
        expect(instance).to receive(:associate).and_return(bike)
        expect(instance).to receive(:validate_record).and_return(bike)
        new_bike = Bike.new(
          creation_organization_id: organization.id,
          propulsion_type: "sail",
          cycle_type: "stroller",
          serial_number: "BIKE TOKENd",
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: false,
          rear_wheel_size_id: wheel_size.id,
          primary_frame_color_id: color.id,
          handlebar_type: "bmx",
          creator: user
        )
        expect {
          instance.send(:save_bike, new_bike)
        }.to change(Bike, :count).by(1)
        expect(b_param.skip_owner_email?).to be_falsey
      end
    end

    it "enque listing order working" do
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.fake! do
        bike = FactoryBot.create(:bike)
        expect(instance).to receive(:associate).and_return(bike)
        expect(instance).to receive(:validate_record).and_return(bike)
        expect {
          instance.send(:save_bike, bike)
        }.to change(AfterBikeSaveWorker.jobs, :size).by(1)
      end
    end
  end

  describe "create_bike" do
    it "saves the bike" do
      Sidekiq::Testing.inline! do
        bike = Bike.new
        expect(instance).to receive(:add_bike_book_data).at_least(1).times.and_return(nil)
        expect(instance).to receive(:find_or_build_bike).at_least(1).times.and_return(bike)
        expect(bike).to receive(:save).at_least(:once).and_return(true)
        instance.create_bike
      end
    end
    context "organized" do
      it "creates" do
        organization = FactoryBot.create(:organization)
        user = FactoryBot.create(:user)
        manufacturer = FactoryBot.create(:manufacturer)
        color = FactoryBot.create(:color)
        wheel_size = FactoryBot.create(:wheel_size)
        b_param = BParam.create(creator: user, params: {
          bike: {
            creation_organization_id: organization.id,
            propulsion_type: "sail",
            cycle_type: "stroller",
            serial_number: "BIKE TOKENd",
            manufacturer_id: manufacturer.id,
            rear_tire_narrow: false,
            rear_wheel_size_id: wheel_size.id,
            primary_frame_color_id: color.id,
            handlebar_type: "bmx",
            owner_email: "stuff@stuff.com"
          }
        })
        instance = subject.new(b_param)
        expect { instance.create_bike }.to change(Bike, :count).by(1)
        expect(b_param.skip_owner_email?).to be_falsey
        bike = Bike.last
        expect(bike.creation_organization_id).to eq organization.id
        expect(bike.bike_organizations.count).to eq 1
        expect(bike.bike_organizations.first.can_edit_claimed).to be_truthy
      end
    end

    it "returns the bike instead of saving if the bike has errors" do
      bike = Bike.new(serial_number: "LOLZ")
      bike.errors.add(:errory, "something")
      expect(instance).to receive(:find_or_build_bike).and_return(bike)
      response = instance.create_bike
      expect(response.errors[:errory]).to eq(["something"])
    end
  end

  describe "creating parking_notification bike" do
    let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
    let(:color) { FactoryBot.create(:color) }
    let(:organization) { FactoryBot.create(:organization_with_auto_user) }
    let(:auto_user) { organization.auto_user }
    let!(:creator) { FactoryBot.create(:organization_member, organization: organization) }
    let!(:state) { FactoryBot.create(:state_new_york) }
    let(:attrs) do
      {
        origin: "organization_form",
        creator_id: creator.id,
        params: {
          bike: {
            creation_organization_id: organization.id,
            serial_number: "",
            primary_frame_color_id: color.id,
            manufacturer_id: manufacturer.id
          },
          parking_notification: {
            latitude: "40.7143528",
            longitude: "-74.0059731",
            accuracy: "12",
            kind: "parked_incorrectly_notification",
            internal_notes: "some details about the abandoned thing",
            use_entered_address: "false",
            message: "Some message to the user",
            street: "somewhere"
          }
        }
      }
    end
    let(:b_param) { BParam.create(attrs) }
    it "creates" do
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.inline! do
        ActionMailer::Base.deliveries = []
        expect(creator.id).to_not eq auto_user.id
        expect(b_param.valid?).to be_truthy
        expect(b_param.id).to be_present
        expect(b_param.organization_id).to eq organization.id
        expect(instance).to receive(:add_bike_book_data).at_least(1).times.and_return(nil)
        bike = instance.create_bike
        expect(bike.errors).to_not be_present
        b_param.reload
        expect(b_param.created_bike_id).to eq bike.id
        expect(b_param.skip_owner_email?).to be_truthy

        bike.reload
        expect(bike.creation_organization_id).to eq organization.id
        expect(bike.id).to be_present
        expect(bike.serial_number).to eq "unknown"
        expect(bike.address).to be_present
        expect(bike.latitude).to eq(40.7143528)
        expect(bike.longitude).to eq(-74.0059731)
        expect(bike.owner_email).to eq auto_user.email
        expect(bike.creator).to eq creator
        expect(bike.status).to eq "unregistered_parking_notification"
        expect(bike.user_hidden).to be_truthy
        expect(bike.visible_by?(User.new)).to be_falsey
        expect(bike.visible_by?(auto_user)).to be_truthy
        expect(bike.visible_by?(creator)).to be_truthy
        expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
        expect(bike.bike_organizations.first.can_edit_claimed).to be_truthy

        expect(bike.parking_notifications.count).to eq 1
        parking_notification = bike.current_parking_notification
        expect(parking_notification.organization).to eq organization
        expect(parking_notification.owner_known?).to be_falsey
        expect(parking_notification.latitude).to eq bike.latitude
        expect(parking_notification.longitude).to eq bike.longitude
        expect(parking_notification.address).to eq "278 Broadway, New York, NY 10007"
        expect(parking_notification.kind).to eq "parked_incorrectly_notification"
        expect(parking_notification.message).to eq "Some message to the user"
        expect(parking_notification.internal_notes).to eq "some details about the abandoned thing"
        expect(parking_notification.accuracy).to eq 12.0
        expect(parking_notification.unregistered_bike).to be_truthy
        expect(parking_notification.delivery_status).to be_blank
        # It shouldn't have sent any email
        expect(ActionMailer::Base.deliveries.count).to eq 0
      end
    end
    context "passed address" do
      let(:updated_parking_notification_attrs) do
        {
          latitude: "12",
          longitude: "-44",
          kind: "appears_abandoned_notification",
          internal_notes: "some details about the abandoned thing",
          message: "another note",
          accuracy: "12",
          use_entered_address: "1",
          street: "278 Broadway",
          city: "New York",
          zipcode: "10007",
          state_id: state.id.to_s,
          country_id: Country.united_states.id
        }
      end
      let(:b_param) { BParam.create(attrs.merge(params: attrs[:params].merge(parking_notification: updated_parking_notification_attrs))) }
      it "uses the address" do
        Sidekiq::Worker.clear_all
        Sidekiq::Testing.inline! do
          ActionMailer::Base.deliveries = []
          expect(creator.id).to_not eq auto_user.id
          expect(b_param.valid?).to be_truthy
          expect(b_param.id).to be_present
          expect(b_param.organization_id).to eq organization.id
          expect(instance).to receive(:add_bike_book_data).at_least(1).times.and_return(nil)
          bike = instance.create_bike
          expect(bike.errors).to_not be_present
          b_param.reload
          expect(b_param.created_bike_id).to eq bike.id

          bike.reload
          expect(bike.creation_organization_id).to eq organization.id
          expect(bike.id).to be_present
          expect(bike.serial_number).to eq "unknown"
          expect(bike.address).to be_present
          expect(bike.latitude).to eq(40.7143528)
          expect(bike.longitude).to eq(-74.0059731)
          expect(bike.owner_email).to eq auto_user.email
          expect(bike.creator).to eq creator
          expect(bike.visible_by?(auto_user)).to be_truthy
          expect(bike.visible_by?(creator)).to be_truthy

          expect(bike.parking_notifications.count).to eq 1
          parking_notification = bike.current_parking_notification
          expect(parking_notification.organization).to eq organization
          expect(parking_notification.owner_known?).to be_falsey
          expect(parking_notification.latitude).to eq bike.latitude
          expect(parking_notification.longitude).to eq bike.longitude
          expect(parking_notification.address).to eq "278 Broadway, New York, NY 10007"
          expect(parking_notification.kind).to eq "appears_abandoned_notification"
          expect(parking_notification.message).to eq "another note"
          expect(parking_notification.internal_notes).to eq "some details about the abandoned thing"
          expect(parking_notification.accuracy).to eq 12.0
          # It shouldn't have sent any email
          expect(ActionMailer::Base.deliveries.count).to eq 0
        end
      end
    end
  end

  describe "create impounded bike" do
    let!(:state) { FactoryBot.create(:state_new_york) }
    let(:user) { FactoryBot.create(:user) }
    let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
    let(:color) { FactoryBot.create(:color) }
    let(:bike_params) do
      {
        serial_number: "s0s0s0s11111 4321212",
        primary_frame_color_id: color.id,
        secondary_frame_color_id: color.id,
        manufacturer_id: manufacturer.id,
        owner_email: user.email
      }
    end
    let(:impound_record_params) { {street: "278 Broadway", city: "New York", zipcode: "10007", state_id: state.id.to_s, country_id: Country.united_states.id} }
    # This the same way b_param is treated in bikes_controller
    let(:b_param) { BParam.new(creator: user) }
    before { b_param.clean_params({bike: bike_params, impound_record: impound_record_params}) }
    it "creates impounded bike" do
      expect(b_param.stolen_attrs).to be_blank
      expect(b_param.impound_attrs).to eq impound_record_params.as_json
      expect(b_param.status).to eq "status_impounded"
      bike = instance.create_bike
      expect(b_param.bike_errors).to be_blank
      expect(b_param.skip_owner_email?).to be_truthy
      expect(bike.id).to be_present
      expect_attrs_to_match_hash(bike, bike_params)
      expect(bike.status).to eq "status_impounded"
      expect(bike.status_humanized).to eq "found"
      expect(bike.impound_records.count).to eq 1
      impound_record = bike.impound_records.last
      expect_attrs_to_match_hash(bike, bike_params)
      expect(impound_record.id).to eq bike.current_impound_record&.id
      expect(impound_record.status).to eq "current"
      expect(impound_record.organized?).to be_falsey
      expect(impound_record.user).to eq user
      expect(impound_record.display_id).to be_blank
      expect(impound_record.to_coordinates).to eq([default_location[:latitude], default_location[:longitude]])
      ownership = bike.current_ownership
      expect(ownership.send_email).to be_falsey
      expect(ownership.impound_record_id).to eq impound_record.id
    end
    context "failing" do
      let(:bike_params) { {serial_number: "fassdfasdf"} }
      it "deletes the record" do
        expect(ImpoundRecord.count).to eq 0
        bike = instance.create_bike
        expect(b_param.bike_errors).to be_present
        expect(bike.id).to be_blank
        expect(ImpoundRecord.count).to eq 0
      end
    end
  end

  describe "build_bike" do
    let(:b_param_params) { {} }
    let(:b_param) { BParam.new(params: b_param_params) }
    let(:bike) { instance.build_bike }
    it "builds it" do
      expect(bike.status).to eq "status_with_owner"
      expect(bike.id).to be_blank
    end
    context "status impounded" do
      let(:b_param_params) { {bike: {status: "status_impounded"}} }
      it "is abandoned" do
        expect(b_param.status).to eq "status_impounded"
        expect(b_param.impound_attrs).to be_blank
        expect(bike.id).to be_blank
        impound_record = bike.impound_records.last
        expect(impound_record).to be_present
        expect(impound_record.kind).to eq "found"
        expect(bike.status_humanized).to eq "found"
      end
      context "with impound attrs" do
        let(:time) { Time.current - 12.hours }
        let(:b_param_params) { {bike: {status: "status_with_owner"}, impound_record: {impounded_at: time}} }
        it "is abandoned" do
          expect(b_param.status).to eq "status_impounded"
          expect(b_param.impound_attrs).to be_present
          expect(bike.id).to be_blank
          impound_record = bike.impound_records.last
          expect(impound_record).to be_present
          expect(impound_record.kind).to eq "found"
          expect(impound_record.impounded_at).to be_within(1).of time
          expect(bike.status_humanized).to eq "found"
        end
      end
    end
    context "status stolen" do
      let(:b_param_params) { {bike: {status: "status_stolen"}} }
      it "is stolen" do
        expect(b_param).to be_valid
        expect(b_param.status).to eq "status_stolen"
        expect(b_param.stolen_attrs).to be_blank
        expect(bike.status).to eq "status_stolen"
        expect(bike.id).to be_blank
        expect(bike.stolen_records.last).to be_present
      end
      context "legacy_stolen" do
        let(:b_param_params) { {bike: {stolen: true}} }
        it "is stolen" do
          expect(b_param).to be_valid
          expect(b_param.status).to eq "status_stolen"
          expect(b_param.stolen_attrs).to be_blank
          expect(bike.status).to eq "status_stolen"
          expect(bike.id).to be_blank
          expect(bike.stolen_records.last).to be_present
        end
      end
    end
    context "with id" do
      let(:b_param) { FactoryBot.create(:b_param, params: b_param_params) }
      it "includes ID" do
        expect(b_param).to be_valid
        expect(bike.status).to eq "status_with_owner"
        expect(bike.id).to be_blank
        expect(bike.b_param_id).to eq b_param.id
        expect(bike.b_param_id_token).to eq b_param.id_token
        expect(bike.creator).to eq b_param.creator
      end
      context "stolen" do
        # Even though status_with_owner passed - since it has stolen attrs
        let(:b_param_params) { {bike: {status: "status_with_owner"}, stolen_record: {phone: "7183839292"}} }
        it "is stolen" do
          expect(b_param).to be_valid
          expect(b_param.status).to eq "status_stolen"
          expect(b_param.stolen_attrs).to eq b_param_params[:stolen_record].as_json
          expect(bike.status).to eq "status_stolen"
          expect(bike.id).to be_blank
          expect(bike.b_param_id).to eq b_param.id
          expect(bike.b_param_id_token).to eq b_param.id_token
          expect(bike.creator).to eq b_param.creator
          stolen_record = bike.stolen_records.last
          expect(stolen_record).to be_present
          expect(stolen_record.phone).to eq b_param_params.dig(:stolen_record, :phone)
        end
      end
    end
    context "status overrides" do
      it "is stolen if it is stolen" do
        bike = instance.build_bike(status: "status_stolen")
        expect(bike.status).to eq "status_stolen"
      end
      it "impounded if status_impounded" do
        bike = instance.build_bike(status: "status_impounded")
        expect(bike.status).to eq "status_impounded"
      end
    end
  end

  # Old BikeCreatorAssociator specs
  describe "create_ownership" do
    it "calls create ownership" do
      bike = Bike.new
      allow(b_param).to receive(:params).and_return({bike: bike}.as_json)
      allow(b_param).to receive(:creator).and_return("creator")
      expect_any_instance_of(OwnershipCreator).to receive(:create_ownership).and_return(true)
      subject.new(b_param).send("create_ownership", bike)
      expect(b_param.skip_owner_email?).to be_falsey
    end
    it "calls create ownership with send_email false if b_param has that" do
      bike = Bike.new
      allow(b_param).to receive(:params).and_return({bike: {send_email: false}}.as_json)
      allow(b_param).to receive(:creator).and_return("creator")
      expect_any_instance_of(OwnershipCreator).to receive(:create_ownership).and_return(true)
      subject.new(b_param).send("create_ownership", bike)
      expect(b_param.skip_owner_email?).to be_truthy
    end
  end

  describe "add_other_listings" do
    it "calls create stolen record" do
      bike = FactoryBot.create(:bike)
      urls = ["http://some_blog.com", "http://some_thing.com"]
      allow(b_param).to receive(:params).and_return({bike: {other_listing_urls: urls}}.as_json)
      subject.new(b_param).send("add_other_listings", bike)
      expect(bike.other_listings.reload.pluck(:url)).to eq(urls)
    end
  end

  describe "attach_photo" do
    it "creates public images for the attached image" do
      bike = FactoryBot.create(:bike)
      b_param = FactoryBot.create(:b_param)
      test_photo = Rack::Test::UploadedFile.new(File.open(File.join(Rails.root, "spec", "fixtures", "bike.jpg")))
      b_param.image = test_photo
      b_param.save
      expect(b_param.image).to be_present
      b_param.params = p
      subject.new(b_param).attach_photo(bike)
      expect(bike.public_images.count).to eq(1)
    end
  end

  describe "updated_phone" do
    let(:user) { FactoryBot.create(:user) }
    let(:bike) { Bike.new(phone: "699.999.9999") }
    before { allow(bike).to receive(:user) { user } }
    it "sets the owner's phone if one is passed in" do
      instance.send("assign_user_attributes", bike)
      user.reload
      expect(user.phone).to eq("6999999999")
    end
    context "user already has a phone" do
      let(:user) { FactoryBot.create(:user, phone: "0000000000") }
      it "does not set the phone if the user already has a phone" do
        instance.send("assign_user_attributes", bike)
        user.reload
        expect(user.phone).to eq("0000000000")
      end
    end
  end

  describe "associate" do
    let(:b_param) { nil }
    it "rescues from the error and add the message to the bike" do
      expect(StolenRecordUpdator).to be_present # Load the error
      bike = Bike.new(status: "status_stolen")
      instance.send("associate", bike)
      expect(bike.errors.messages[:association_error]).not_to be_nil
    end
  end
end
