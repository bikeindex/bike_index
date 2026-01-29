require "rails_helper"

RSpec.describe BikeServices::Creator do
  let(:subject) { described_class }
  let(:user) { FactoryBot.create(:user) }
  let(:bike_params) { {} }
  let(:b_param) { BParam.create(creator: user, params: {bike: bike_params}) }
  let(:instance) { subject.new(ip_address:) }
  # Frequently used associations
  let(:organization) { FactoryBot.create(:organization) }
  let(:color) { FactoryBot.create(:color) }
  let(:manufacturer_name) { "Trek" }
  let(:manufacturer) { FactoryBot.create(:manufacturer, name: manufacturer_name) }
  let(:ip_address) { "127.0.0.1" }

  describe "create_bike" do
    context "errors" do
      context "owner_email format error" do
        let(:bike_params) do
          {
            serial_number: "Serial 1",
            manufacturer_id: manufacturer.id,
            rear_tire_narrow: "false",
            primary_frame_color_id: color.id,
            owner_email: "stuff@fffff"
          }
        end
        it "error is helpful" do
          Sidekiq::Testing.inline! do
            expect(Bike.count).to eq 0
            bike = instance.create_bike(b_param)
            expect(Bike.count).to eq 0
            expect(bike.errors.count).to eq 1
            expect(bike.errors.full_messages.first).to match(/email invalid/i)
          end
        end
      end
    end

    describe "existing_bike" do
      let!(:existing_bike) { FactoryBot.create(:bike) }
      it "does not create" do
        instance # instantiate - then update
        b_param.update(created_bike_id: existing_bike.id)
        expect {
          bike = instance.create_bike(b_param)
          expect(bike.id).to eq existing_bike.id
        }.to change(BikeOrganization, :count).by 0
      end
    end

    context "e_motor_checkbox true" do
      let(:default_params) do
        {
          bike: {
            primary_frame_color_id: color.id,
            manufacturer_id: manufacturer.id,
            owner_email: "something@stuff.com",
            cycle_type: cycle_type
          },
          propulsion_type_motorized: true,
          propulsion_type_throttle: true,
          propulsion_type_pedal_assist: true
        }
      end
      let(:passed_params) { default_params }
      let(:cycle_type) { "cargo" }
      let(:b_param) { BParam.create(creator: user, params: passed_params) }
      it "creates an e-bike vehicle" do
        expect(BikeOrganization.count).to eq 0
        expect {
          instance.create_bike(b_param)
        }.to change(Bike, :count).by 1
        expect(BikeOrganization.count).to eq 0
        bike = Bike.last
        expect(bike.creator&.id).to eq user.id
        expect(bike.current_ownership&.id).to be_present
        expect(bike.claimed?).to be_falsey
        expect(bike).to match_hash_indifferently passed_params[:bike].merge(propulsion_type: "pedal-assist-and-throttle")
        expect(bike.motorized?).to be_truthy
        expect(Bike.motorized.count).to eq 1
      end
      context "not pedal cycle_type" do
        let(:cycle_type) { "wheelchair" }
        it "creates an e-bike" do
          expect(BikeOrganization.count).to eq 0
          expect {
            instance.create_bike(b_param)
          }.to change(Bike, :count).by 1
          expect(BikeOrganization.count).to eq 0
          bike = Bike.last
          expect(bike).to match_hash_indifferently passed_params[:bike].merge(propulsion_type: "throttle")
          expect(bike.motorized?).to be_truthy
        end
      end
      context "not motorizable cycle_type" do
        let(:cycle_type) { "trail-behind" }
        it "creates a non motorized vehicle" do
          expect(BikeOrganization.count).to eq 0
          expect {
            instance.create_bike(b_param)
          }.to change(Bike, :count).by 1
          expect(BikeOrganization.count).to eq 0
          bike = Bike.last
          expect(bike).to match_hash_indifferently passed_params[:bike].merge(propulsion_type: "foot-pedal")
          expect(bike.motorized?).to be_falsey
          expect(Bike.motorized.count).to eq 0
        end
      end
    end

    describe "with organization" do
      let(:default_params) do
        {
          primary_frame_color_id: color.id,
          creation_organization_id: organization&.id,
          manufacturer_id: manufacturer.id,
          owner_email: "something@stuff.com"
        }
      end
      let(:bike_params) { default_params }
      let(:target_created_attrs) { bike_params.merge(cycle_type: "bike", propulsion_type: "foot-pedal") }
      context "no organization" do
        let(:organization) { nil }
        it "creates" do
          expect {
            instance.create_bike(b_param)
          }.to change(BikeOrganization, :count).by 0
          bike = Bike.last
          expect(bike.creator&.id).to eq user.id
          expect(bike.current_ownership&.id).to be_present
          expect(bike).to match_hash_indifferently target_created_attrs
        end
      end
      context "with organization" do
        it "creates the bike_organization", :flaky do
          expect {
            instance.create_bike(b_param)
          }.to change(BikeOrganization, :count).by 1
          bike = Bike.last
          expect(bike.creator&.id).to eq user.id
          expect(bike.current_ownership&.id).to be_present
          expect(bike.bike_organizations.first.organization).to eq organization
          expect(bike.bike_organizations.first.can_edit_claimed).to be_truthy
          expect(bike).to match_hash_indifferently target_created_attrs
        end
        context "with spam_registrations" do
          let(:organization) { FactoryBot.create(:organization, spam_registrations: true) }
          let(:b_param_params) do
            {
              bike: default_params.merge(
                frame_model: "2yynzfIfyiDCltHWjDDgWPr",
                manufacturer_id: Manufacturer.other.id,
                manufacturer_other: "qetasdgf8asdf00afdddvxcvxcvxc"
              ),
              stolen_record: {
                phone: "7183839292",
                theft_description: "asdfasdfg89xcv89sdf9asdfsdfffffffff"
              }
            }
          end
          let!(:b_param) { BParam.create(creator: user, params: b_param_params) }
          let(:target_created_attrs) { b_param_params[:bike].merge(cycle_type: "bike", propulsion_type: "foot-pedal") }
          it "creates the bike_organization" do
            Sidekiq::Job.clear_all
            ActionMailer::Base.deliveries = []

            expect {
              instance.create_bike(b_param)
            }.to change(BikeOrganization, :count).by 1
            Email::OwnershipInvitationJob.drain
            # CRITICAL - this needs to not deliver email, or else we're spamming people
            expect(ActionMailer::Base.deliveries.count).to eq 0

            bike = Bike.unscoped.last
            expect(SpamEstimator.estimate_bike(bike)).to eq 100
            expect(bike.creator&.id).to eq user.id
            expect(bike.current_ownership&.id).to be_present
            expect(bike.likely_spam).to be_truthy
            expect(bike.bike_organizations.first.organization).to eq organization
            expect(bike.bike_organizations.first.can_edit_claimed).to be_truthy
            expect(bike).to match_hash_indifferently target_created_attrs
          end
        end
      end
      context "child organization" do
        let(:organization_parent) { FactoryBot.create(:organization) }
        let(:organization) { FactoryBot.create(:organization_child, parent_organization: organization_parent) }
        it "creates the bike_organization for both", :flaky do
          expect {
            instance.create_bike(b_param)
          }.to change(BikeOrganization, :count).by 2
          bike = Bike.last
          expect(bike.creator&.id).to eq user.id
          expect(bike.current_ownership&.id).to be_present
          expect(bike.creation_organization_id).to eq organization.id
          expect(bike.bike_organizations.count).to eq 2
          expect(bike.organizations.pluck(:id)).to match_array([organization.id, organization_parent.id])
          expect(bike.can_edit_claimed_organizations.pluck(:id)).to match_array([organization.id, organization_parent.id])
          expect(bike.current_ownership_id).to be_present
          expect(bike).to match_hash_indifferently target_created_attrs
        end
      end
      context "extra attributes" do
        let(:manufacturer_name) { "BH Bikes (Beistegui Hermanos)" }
        let(:wheel_size) { FactoryBot.create(:wheel_size) }
        let(:bike_params) { default_params.merge(extra_attributes) }
        let(:extra_attributes) do
          {
            creation_organization_id: organization.id,
            manufacturer_id: Manufacturer.other.id,
            manufacturer_other: "BH", # It looks up the manufacturer
            propulsion_type_slug: "hand-pedal",
            cycle_type: "stroller",
            serial_number: "BIKE TOKENd",
            rear_tire_narrow: false,
            rear_wheel_size_id: wheel_size.id,
            handlebar_type: "bmx",
            owner_email: "stuff@stuff.com",
            user_name: "Sally",
            address_record_attributes: {
              street: "Somewhere Ville"
            }
          }
        end
        let(:not_matched_attrs) { %i[user_name propulsion_type_slug manufacturer_id manufacturer_other street address_record_attributes] }
        let(:target_address_record) do
          {street: "Somewhere Ville", kind: "ownership", publicly_visible_attribute: "postal_code"}
        end

        def expect_bike_created_with_extra_attrs
          expect { instance.create_bike(b_param) }.to change(Bike, :count).by(1)
            .and change(AddressRecord, :count).by(1)

          expect(b_param.skip_email?).to be_falsey
          bike = Bike.last
          expect(bike.creation_organization_id).to eq organization.id
          expect(bike.bike_organizations.count).to eq 1
          expect(bike.bike_organizations.first.can_edit_claimed).to be_truthy
          expect(bike.registration_address.compact).to eq({"street" => "Somewhere Ville"})
          expect(BikeServices::CalculateLocation.registration_address_source(bike)).to eq "initial_creation"
          expect(bike.address_record.attributes.compact.symbolize_keys.except(:id, :updated_at, :created_at)).to eq target_address_record.merge(bike_id: bike.id)

          expect(bike).to match_hash_indifferently bike_params.except(*not_matched_attrs)
          expect(bike.manufacturer_id).to eq manufacturer.id
          expect(bike.manufacturer_other).to be_nil
          expect(bike.mnfg_name).to eq "BH Bikes" # Because that's the short name
          expect(bike.propulsion_type).to eq "human-not-pedal"
          # Test that front_wheel is assigned via rear wheel attr
          expect(bike.front_wheel_size_id).to eq wheel_size.id
          expect(bike.front_tire_narrow).to be_falsey

          # And then test ownership
          expect(bike.ownerships.count).to eq 1
          ownership = bike.ownerships.first
          expect(bike.current_ownership_id).to eq ownership.id
          expect(ownership.organization_id).to eq organization.id
          expect(ownership.owner_email).to eq "stuff@stuff.com"
          expect(ownership.owner_name).to eq "Sally"
          expect(ownership.address_hash_legacy.reject { |_k, v| v.blank? }).to eq({"street" => "Somewhere Ville"})
        end

        it "creates" do
          expect_bike_created_with_extra_attrs
        end
      end
    end

    describe "creating parking_notification bike" do
      let(:manufacturer_name) { "Surly" }
      let(:organization) { FactoryBot.create(:organization_with_auto_user) }
      let(:auto_user) { organization.auto_user }
      let!(:creator) { FactoryBot.create(:organization_user, organization: organization) }
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
        Sidekiq::Job.clear_all
        Sidekiq::Testing.inline! do
          ActionMailer::Base.deliveries = []
          expect(creator.id).to_not eq auto_user.id
          expect(b_param.valid?).to be_truthy
          expect(b_param.id).to be_present
          expect(b_param.organization_id).to eq organization.id
          expect(instance).to receive(:add_bike_book_data).at_least(1).times.and_return(nil)
          bike = instance.create_bike(b_param)
          expect(bike.errors).to_not be_present
          b_param.reload
          expect(b_param.created_bike_id).to eq bike.id
          expect(b_param.skip_email?).to be_truthy

          bike.reload
          expect(bike.creation_organization_id).to eq organization.id
          expect(bike.id).to be_present
          expect(bike.serial_number).to eq "unknown"
          expect(bike.latitude).to eq(40.7143528)
          expect(bike.longitude).to eq(-74.0059731)
          expect(bike.owner_email).to eq auto_user.email
          expect(bike.creator).to eq creator
          expect(bike.status).to eq "unregistered_parking_notification"
          expect(bike.user_hidden).to be_truthy
          expect(bike.current_ownership.status).to eq "unregistered_parking_notification"
          expect(bike.current_ownership.origin).to eq "creator_unregistered_parking_notification"
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
          # Sanity check
          expect(parking_notification.longitude.to_s).to eq attrs.dig(:params, :parking_notification, :longitude)
          expect(parking_notification.street).to eq "278 Broadway"
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
          Sidekiq::Job.clear_all
          Sidekiq::Testing.inline! do
            ActionMailer::Base.deliveries = []
            expect(creator.id).to_not eq auto_user.id
            expect(b_param.valid?).to be_truthy
            expect(b_param.id).to be_present
            expect(b_param.organization_id).to eq organization.id
            expect(instance).to receive(:add_bike_book_data).at_least(1).times.and_return(nil)
            bike = instance.create_bike(b_param)
            expect(bike.errors).to_not be_present
            b_param.reload
            expect(b_param.created_bike_id).to eq bike.id

            bike.reload
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

    describe "create impounded bike" do
      let!(:state) { FactoryBot.create(:state_new_york) }
      let(:manufacturer_name) { "Surly" }
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
        bike = instance.create_bike(b_param)
        expect(b_param.bike_errors).to be_blank
        expect(b_param.skip_email?).to be_truthy
        expect(bike.id).to be_present
        expect(bike).to match_hash_indifferently bike_params
        expect(bike.cycle_type).to eq "bike"
        expect(bike.status).to eq "status_impounded"
        expect(bike.status_humanized).to eq "found"
        expect(bike.impound_records.count).to eq 1
        impound_record = bike.impound_records.last
        expect(bike).to match_hash_indifferently bike_params
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
          bike = instance.create_bike(b_param)
          expect(b_param.bike_errors).to be_present
          expect(bike.id).to be_blank
          expect(ImpoundRecord.count).to eq 0
        end
      end
    end

    describe "no_duplicate" do
      let(:serial) { "some serial number" }
      let!(:existing_bike) { FactoryBot.create(:bike, :with_ownership, serial_number: serial, owner_email: email, manufacturer: manufacturer) }
      let(:user) { existing_bike.creator }
      let(:default_params) do
        {
          primary_frame_color_id: color.id,
          manufacturer_id: manufacturer.id,
          serial_number: "#{serial.upcase} ",
          owner_email: new_email,
          no_duplicate: true
        }
      end
      let(:bike_params) { default_params }
      let(:email) { "something@gmail.com" }
      let(:new_email) { "Something@GMAIL.com" }
      let(:found_duplicate) { BikeServices::OwnerDuplicateFinder.matching(serial: bike_params[:serial_number], owner_email: bike_params[:owner_email], manufacturer_id: bike_params[:manufacturer_id]).first }
      def expect_duplicate_found
        expect(b_param.no_duplicate?).to be_truthy
        expect(found_duplicate&.id).to eq existing_bike.id
        expect(instance.create_bike(b_param)&.id).to eq existing_bike.id
        b_param.reload
        expect(b_param.created_bike_id).to eq existing_bike.id
        expect(Bike.unscoped.pluck(:id)).to match_array([existing_bike.id])
      end

      def expect_no_duplicate
        expect(b_param.no_duplicate?).to be_truthy
        expect(found_duplicate&.id).to be_blank
        bike = instance.create_bike(b_param)
        expect(bike.id).to_not eq existing_bike.id
        b_param.reload
        expect(b_param.created_bike_id).to eq bike.id
      end
      it "finds a duplicate" do
        expect_duplicate_found
      end
      context "no_duplicate false" do
        let(:bike_params) { default_params.merge(no_duplicate: false) }
        it "finds a duplicate" do
          expect(found_duplicate&.id).to eq existing_bike.id
          bike = instance.create_bike(b_param)
          expect(bike.id).to_not eq existing_bike.id
          b_param.reload
          expect(b_param.created_bike_id).to eq bike.id
        end
      end
      context "different manufacturer" do
        let(:bike_params) { default_params.merge(manufacturer_id: FactoryBot.create(:manufacturer).id) }
        it "doesn't find the duplicate" do
          expect_no_duplicate
        end
      end
      context "different email" do
        let(:email) { "something@gmail.com" }
        let(:new_email) { "newsomething@gmail.com" }
        it "does not find a non-duplicate" do
          expect_no_duplicate
        end
      end
      context "existing bike with made_without_serial serial" do
        let(:serial) { "made_without_serial" }
        it "finds no duplicate" do
          expect(existing_bike.serial_normalized).to be_blank
          expect_no_duplicate
        end
        context "unknown serial" do
          let(:bike_params) { default_params.merge(serial_number: "unknown") }
          it "finds no duplicate" do
            expect(existing_bike.serial_normalized).to be_blank
            expect_no_duplicate
          end
        end
      end
      context "user_hidden" do
        it "finds duplicate" do
          existing_bike.update(marked_user_hidden: true)
          expect(existing_bike.reload.user_hidden).to be_truthy
          expect(b_param.reload.created_bike_id).to be_blank
          expect(b_param.no_duplicate?).to be_truthy
          expect(Bike.unscoped.pluck(:id)).to match_array([existing_bike.id])
          expect(Bike.with_user_hidden.pluck(:id)).to match_array([existing_bike.id])
          expect(Ownership.count).to eq 1
          expect(found_duplicate&.id).to eq existing_bike.id
          expect(instance.create_bike(b_param)&.id).to eq existing_bike.id
          expect(b_param.reload.created_bike_id).to eq existing_bike.id
          expect(Ownership.count).to eq 1
          # And you can call it again and the result is the same
          expect(instance.create_bike(b_param)&.id).to eq existing_bike.id
          expect(Ownership.count).to eq 1
        end
      end
      context "deleted" do
        it "does not find duplicate" do
          existing_bike.destroy
          expect(b_param.no_duplicate?).to be_truthy
          expect(Bike.unscoped.pluck(:id)).to match_array([existing_bike.id])
          expect(Bike.with_user_hidden.pluck(:id)).to match_array([])
          expect(Ownership.count).to eq 1
          bike = instance.create_bike(b_param)
          expect(Bike.pluck(:id)).to match_array([bike.id])
          expect(Bike.unscoped.pluck(:id)).to match_array([existing_bike.id, bike.id])
          expect(b_param.reload.created_bike_id).to eq bike.id
          # And calling it again doesn't change anything
          instance.create_bike(b_param)
          expect(Bike.pluck(:id)).to match_array([bike.id])
          expect(Bike.unscoped.pluck(:id)).to match_array([existing_bike.id, bike.id])
          expect(Ownership.count).to eq 2
        end
      end
    end

    describe "with ip_address, doorkeeper_app_id and ios_version" do
      before { allow(GeocodeHelper).to receive(:assignable_address_hash_for).and_return(address_hash) }
      let(:address_hash) do
        {kind: "ownership", city: "Casper", latitude: 42.8489653, longitude: -106.3014667, postal_code: "82601",
         region_string: "WY", country_id: Country.united_states_id, street: "1740 East 2nd Street"}
      end
      let(:bike_params) do
        {primary_frame_color_id: color.id, manufacturer_id: manufacturer.id,
         owner_email: "something@stuff.com", ios_version: "1.6.9"}
      end
      let(:b_param) { BParam.create(creator: user, params: {bike: bike_params}.as_json, doorkeeper_app_id: 69) }

      it "adds an address_record" do
        expect(AddressRecord.count).to eq 0
        bike = instance.create_bike(b_param)
        expect(AddressRecord.count).to eq 1
        expect(bike).to be_valid
        expect(bike.current_ownership.registration_info).to match_hash_indifferently({ip_address:, ios_version: "1.6.9"})
        expect(bike.current_ownership.doorkeeper_app_id).to eq 69
        expect(bike.address_record).to be_present
        expect(bike.address_record).to have_attributes address_hash
      end
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
      b_param.params = {}
      instance.attach_photo(b_param, bike)
      expect(bike.public_images.count).to eq(1)
    end
  end

  # Private method (legacy spec)
  describe "updated_phone" do
    let(:bike) { Bike.new(phone: "699.999.9999") }
    before { allow(bike).to receive(:user) { user } }

    it "sets the owner's phone if one is passed in" do
      instance.send(:assign_user_attributes, bike)
      user.reload
      expect(user.phone).to eq("6999999999")
    end
    context "user already has a phone" do
      let(:user) { FactoryBot.create(:user, phone: "0000000000") }
      it "does not set the phone if the user already has a phone" do
        instance.send(:assign_user_attributes, bike)
        user.reload
        expect(user.phone).to eq("0000000000")
      end
    end
  end

  describe "clear_bike" do
    it "removes the existing bike and transfer the errors to a new active record object" do
      b_param = BParam.new
      bike = FactoryBot.create(:bike)
      bike.errors.add(:rando_error, "LOLZ")
      creator = BikeServices::Creator.new.send(:clear_bike, b_param, bike)
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
      instance.send(:validate_record, b_param, bike)
    end

    it "associates the b_param with the bike and clear the bike_errors if the bike is created" do
      bike = Bike.new
      allow(b_param).to receive(:id).and_return(42)
      allow(bike).to receive(:id).and_return(69)
      allow(bike).to receive(:errors).and_return(nil)
      expect(b_param).to receive(:update).with(created_bike_id: 69, bike_errors: nil)
      instance.send(:validate_record, b_param, bike)
    end
  end

  describe "include_bike_book" do
    it "returns the bike if stuff isn't present" do
      expect(instance.send(:add_bike_book_data)).to be_nil
    end
    context "se data" do
      let(:manufacturer_name) { "SE Bikes" }
      let(:bike_params) do
        {
          serial_number: "Some serial",
          description: "Input description",
          manufacturer_id: manufacturer.id,
          year: 2014,
          frame_model: "Draft",
          primary_frame_color_id: color.id
        }
      end
      it "adds se bike data if it exists" do
        VCR.use_cassette("bike_creator-include_bike_book", re_record_interval: 6.months) do
          instance.send(:add_bike_book_data, b_param)

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
  end
end
