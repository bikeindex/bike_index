require "rails_helper"

RSpec.describe BikeCreator do
  context "legacy BikeCreatorBuilder methods" do
    describe "building" do
      it "returns a new bike object from the params with the b_param_id" do
        b_param = BParam.new
        allow(b_param).to receive(:id).and_return(9)
        allow(b_param).to receive(:creator_id).and_return(6)
        allow(b_param).to receive(:params).and_return({ bike: { serial_number: "AAAA" } }.as_json)
        bike = BikeCreator.new(b_param).build_bike
        expect(bike.serial_number).to eq("AAAA")
        expect(bike.updator_id).to eq(6)
        expect(bike.b_param_id).to eq(9)
      end
    end

    describe "add_front_wheel_size" do
      it "sets the front wheel equal to the rear wheel if it's present" do
        bike = Bike.new
        b_param = BParam.new
        allow(bike).to receive(:rear_wheel_size_id).and_return(1)
        allow(bike).to receive(:rear_tire_narrow).and_return(true)
        BikeCreator.new(b_param).send(:add_front_wheel_size, bike)
        expect(bike.front_wheel_size_id).to eq(1)
        expect(bike.rear_tire_narrow).to be_truthy
      end
    end

    describe "add_required_attributes" do
      it "calls the methods it needs to call" do
        bike = Bike.new
        b_param = BParam.new
        creator = BikeCreator.new(b_param)
        creator.send(:add_required_attributes, bike)
        expect(bike.cycle_type).to eq("bike")
        expect(bike.propulsion_type).to eq("foot-pedal")
      end
    end

    describe "find_or_build_bike" do
      it "calls verified bike on new bike and return the bike" do
        bike = Bike.new
        creator = BikeCreator.new
        expect(creator).to receive(:build_bike).and_return(bike)
        allow(creator).to receive(:add_required_attributes).and_return(bike)
        expect(creator.send(:find_or_build_bike)).to eq(bike)
      end
    end

    describe "build" do
      it "returns the b_param bike if one exists" do
        b_param = BParam.new
        bike = Bike.new
        # allow(b_param).to receive(:bike).and_return(bike)
        allow(b_param).to receive(:created_bike).and_return(bike)
        expect(BikeCreator.new(b_param).send(:find_or_build_bike)).to eq(bike)
      end
    end
  end

  describe "include_bike_book" do
    it "returns the bike if stuff isn't present" do
      creator = BikeCreator.new
      expect(creator.send(:add_bike_book_data)).to be_nil
    end
    it "adds se bike data if it exists" do
      manufacturer = FactoryBot.create(:manufacturer, name: "SE Bikes")
      color = FactoryBot.create(:color)
      bike = {
        serial_number: "Some serial",
        description: "Input description",
        manufacturer_id: manufacturer.id,
        year: 2014,
        frame_model: "Draft",
        primary_frame_color_id: color.id,
      }
      b_param = FactoryBot.create(:b_param, params: { bike: bike })
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
      b_param = BParam.new
      bike = Bike.new
      allow(b_param).to receive(:bike).and_return(bike)
      allow(bike).to receive(:errors).and_return(messages: "some errors")
      creator = BikeCreator.new(b_param)
      expect(creator).to receive(:clear_bike).and_return(bike)
      creator.send(:validate_record, bike)
    end

    it "calls delete the already existing bike if one exists" do
      # This is to clean up duplicates, people press the 'add bike button' many times when its slow to respond
      b_param = BParam.new
      bike = FactoryBot.create(:bike)
      bike1 = Bike.new
      allow(b_param).to receive(:created_bike).and_return(bike1)
      expect(BikeCreator.new(b_param).send(:validate_record, bike)).to eq(bike1)
      expect(Bike.where(id: bike1.id)).to be_empty
    end

    it "associates the b_param with the bike and clear the bike_errors if the bike is created" do
      b_param = BParam.new
      bike = Bike.new
      allow(b_param).to receive(:id).and_return(42)
      allow(bike).to receive(:id).and_return(69)
      allow(bike).to receive(:errors).and_return(nil)
      expect(b_param).to receive(:update_attributes).with(created_bike_id: 69, bike_errors: nil)
      BikeCreator.new(b_param).send(:validate_record, bike)
    end
    describe "no_duplicate" do
      let(:existing_bike) { FactoryBot.create(:bike, serial_number: "some serial number", owner_email: email) }
      let(:new_bike) { FactoryBot.create(:bike, serial_number: "some serial number", owner_email: new_email) }
      let!(:ownerships) do
        FactoryBot.create(:ownership, bike: existing_bike, owner_email: email)
        FactoryBot.create(:ownership, bike: new_bike, owner_email: new_email)
      end
      let(:params) do
        {
          bike: {
            serial_number: "some serial number",
            owner_email: new_email,
            no_duplicate: true,
          },
        }
      end
      let(:b_param) { FactoryBot.create(:b_param, creator: existing_bike.current_ownership.creator, params: params) }
      context "same email" do
        let(:email) { "something@gmail.com" }
        let(:new_email) { "Something@GMAIL.com" }
        it "finds a duplicate" do
          expect(b_param.no_duplicate).to be_truthy
          expect(b_param.find_duplicate_bike(new_bike)).to be_truthy
          expect do
            BikeCreator.new(b_param).send(:validate_record, new_bike)
          end.to change(Ownership, :count).by(-1)
          b_param.reload
          expect(b_param.created_bike_id).to eq existing_bike.id
          expect(Bike.where(id: new_bike.id)).to_not be_present
        end
      end
      context "different email" do
        let(:email) { "something@gmail.com" }
        let(:new_email) { "newsomething@gmail.com" }
        it "does not find a non-duplicate" do
          expect(b_param.no_duplicate).to be_truthy
          expect(b_param.find_duplicate_bike(new_bike)).to be_falsey
          expect do
            BikeCreator.new(b_param).send(:validate_record, new_bike)
          end.to change(Ownership, :count).by 0
          b_param.reload
          expect(b_param.created_bike_id).to eq new_bike.id
        end
      end
    end
  end

  describe "save_bike" do
    Sidekiq::Testing.inline! do
      it "creates a bike with the parameters it is passed and returns it" do
        organization = FactoryBot.create(:organization)
        user = FactoryBot.create(:user)
        manufacturer = FactoryBot.create(:manufacturer)
        color = FactoryBot.create(:color)
        wheel_size = FactoryBot.create(:wheel_size)
        b_param = BParam.new(origin: "api_v1")
        creator = BikeCreator.new(b_param)
        bike = Bike.new
        expect_any_instance_of(BikeCreatorAssociator).to receive(:associate).and_return(bike)
        expect(creator).to receive(:validate_record).and_return(bike)
        new_bike = Bike.new(
          creation_organization_id: organization.id,
          propulsion_type: "sail",
          "cycle_type" => "stroller",
          "serial_number" => "BIKE TOKENd",
          "manufacturer_id" => manufacturer.id,
          "rear_tire_narrow" => false,
          "rear_wheel_size_id" => wheel_size.id,
          "primary_frame_color_id" => color.id,
          "handlebar_type" => "bmx",
          "creator" => user,
        )
        expect do
          creator.send(:save_bike, new_bike)
        end.to change(Bike, :count).by(1)
      end
    end

    it "enque listing order working" do
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.fake! do
        b_param = BParam.new
        creator = BikeCreator.new(b_param)
        bike = FactoryBot.create(:bike)
        expect_any_instance_of(BikeCreatorAssociator).to receive(:associate).and_return(bike)
        expect(creator).to receive(:validate_record).and_return(bike)
        expect do
          creator.send(:save_bike, bike)
        end.to change(AfterBikeSaveWorker.jobs, :size).by(1)
      end
    end
  end

  describe "create_bike" do
    Sidekiq::Testing.inline! do
      it "saves the bike" do
        b_param = BParam.new
        bike = Bike.new
        creator = BikeCreator.new(b_param)
        expect(creator).to receive(:add_bike_book_data).at_least(1).times.and_return(nil)
        expect(creator).to receive(:find_or_build_bike).at_least(1).times.and_return(bike)
        expect(bike).to receive(:save).at_least(:once).and_return(true)
        creator.create_bike
      end
    end

    it "returns the bike instead of saving if the bike has errors" do
      b_param = BParam.new
      bike = Bike.new(serial_number: "LOLZ")
      bike.errors.add(:errory, "something")
      creator = BikeCreator.new(b_param)
      expect(creator).to receive(:find_or_build_bike).and_return(bike)
      response = creator.create_bike
      expect(response.errors[:errory]).to eq(["something"])
    end
  end

  describe "creating parking_notification bike" do
    let(:manufacturer) { FactoryBot.create(:manufacturer, name: "SE Bikes") }
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
            manufacturer_id: manufacturer.id,
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
        bike_creator = BikeCreator.new(b_param)
        expect(bike_creator).to receive(:add_bike_book_data).at_least(1).times.and_return(nil)
        bike = bike_creator.create_bike
        expect(bike.errors).to_not be_present
        b_param.reload
        expect(b_param.created_bike_id).to eq bike.id

        expect(bike.creation_organization_id).to eq organization.id
        expect(bike.id).to be_present
        expect(bike.serial_number).to eq "unknown"
        expect(bike.latitude).to eq(40.7143528)
        expect(bike.longitude).to eq(-74.0059731)
        expect(bike.owner_email).to eq auto_user.email
        expect(bike.creator).to eq creator
        expect(bike.status).to eq "unregistered_parking_notification"
        expect(bike.user_hidden).to be_truthy
        expect(bike.visible_by?(User.new)).to be_falsey
        expect(bike.visible_by?(auto_user)).to be_truthy
        expect(bike.visible_by?(creator)).to be_truthy

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
          bike_creator = BikeCreator.new(b_param)
          expect(bike_creator).to receive(:add_bike_book_data).at_least(1).times.and_return(nil)
          bike = bike_creator.create_bike
          expect(bike.errors).to_not be_present
          b_param.reload
          expect(b_param.created_bike_id).to eq bike.id

          expect(bike.creation_organization_id).to eq organization.id
          expect(bike.id).to be_present
          expect(bike.serial_number).to eq "unknown"
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
end
