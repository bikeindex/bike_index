require "rails_helper"

RSpec.describe "BikesController#create", type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bikes" }
  let(:current_user) { FactoryBot.create(:user_confirmed) }
  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let(:color) { Color.black }
  let(:state) { State.find_or_create_by(name: "Illinois", abbreviation: "IL", country: Country.united_states) }
  let(:country) { state.country }
  let(:testable_bike_params) { bike_params.except(:b_param_id_token, :embeded, :cycle_type_slug, :manufacturer_id) }
  let(:basic_bike_params) do
    {
      serial_number: "Bike serial",
      manufacturer_id: manufacturer.name,
      year: "2022",
      frame_model: "Cool frame model",
      primary_frame_color_id: color.id.to_s,
      owner_email: current_user.email
    }
  end
  let(:chicago_stolen_params) do
    {
      country_id: country.id,
      street: "2459 West Division Street",
      city: "Chicago",
      zipcode: "60622",
      state_id: state.id
    }
  end

  context "unverified authenticity token" do
    include_context :test_csrf_token
    it "fails" do
      expect(current_user).to be_present
      expect {
        post base_url, params: {bike: basic_bike_params}
      }.to_not change(Ownership, :count)
      expect(flash[:error]).to match(/verify/i)
    end
  end
  context "blank serials" do
    let(:bike_params) { basic_bike_params.except(:year, :frame_model).merge(serial_number: "unknown", made_without_serial: "0") }
    it "creates" do
      expect(current_user.bikes.count).to eq 0
      expect {
        post base_url, params: {bike: bike_params}
      }.to change(Ownership, :count).by(1)
      expect(current_user.bikes.count).to eq 1
      new_bike = current_user.bikes.first
      expect(new_bike.claimed?).to be_truthy
      expect(new_bike.no_serial?).to be_truthy
      expect(new_bike.made_without_serial?).to be_falsey
      expect(new_bike.current_ownership.origin).to eq "web"
      expect(new_bike.serial_unknown?).to be_truthy
      expect(new_bike.serial_number).to eq "unknown"
      expect(new_bike.normalized_serial_segments).to eq([])
    end
    context "scanned_sticker" do
      let(:organization) { FactoryBot.create(:organization) }
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: organization) }
      it "assigns scanned_sticker", :flaky do
        expect(current_user.bikes.count).to eq 0
        expect(bike_sticker.reload.bike_sticker_updates.count).to eq 0
        expect {
          post base_url, params: {bike: bike_params, bike_sticker: bike_sticker.pretty_code}
        }.to change(Ownership, :count).by(1)
        expect(current_user.reload.bikes.count).to eq 1
        new_bike = current_user.bikes.first
        expect(new_bike.claimed?).to be_truthy
        expect(new_bike.no_serial?).to be_truthy
        expect(new_bike.made_without_serial?).to be_falsey
        expect(new_bike.current_ownership.origin).to eq "sticker"
        expect(new_bike.serial_unknown?).to be_truthy
        expect(new_bike.serial_number).to eq "unknown"
        expect(new_bike.normalized_serial_segments).to eq([])
        expect(new_bike.creation_organization_id).to eq organization.id
        expect(new_bike.creator_id).to eq current_user.id
        expect(new_bike.address_record).to match_hash_indifferently default_location_address_record_attrs.merge(kind: "ownership")
        expect(bike_sticker.reload.bike_sticker_updates.count).to eq 1
        bike_sticker_update = bike_sticker.bike_sticker_updates.last
        expect(bike_sticker_update.kind).to eq "initial_claim"
        expect(bike_sticker_update.failed_claim_errors).to be_blank
        expect(bike_sticker.claimed?).to be_truthy
        expect(new_bike.bike_stickers.pluck(:id)).to eq([bike_sticker.id])
      end
    end
    context "made_without_serial" do
      let(:ip_address) { "fake-ip-address" }
      include_context :geocoder_default_location
      let(:default_location) do
        {country_code: "US", region_code: "CA", state_code: "CA", city: "San Francisco", latitude: 37.75, longitude: -122.41, error: nil}
      end
      it "creates, is made_without_serial" do
        expect(current_user.bikes.count).to eq 0
        expect {
          post base_url, params: {bike: bike_params.merge(made_without_serial: "1")},
            headers: {"HTTP_CF_CONNECTING_IP" => ip_address}
        }.to change(Ownership, :count).by(1)
        expect(current_user.bikes.count).to eq 1
        new_bike = current_user.bikes.first
        expect(new_bike.claimed?).to be_truthy
        expect(new_bike.no_serial?).to be_truthy
        expect(new_bike.made_without_serial?).to be_truthy
        expect(new_bike.serial_unknown?).to be_falsey
        expect(new_bike.serial_number).to eq "made_without_serial"
        expect(new_bike.normalized_serial_segments).to eq([])
        expect(new_bike.current_ownership.impound_record_id).to be_blank
        expect(new_bike.address_record).to be_present
        # new bike coordinates will be set after address record job runs
      end
    end
  end
  context "no existing b_param and stolen" do
    let(:wheel_size) { FactoryBot.create(:wheel_size) }
    let(:extra_long_string) { "Frame Material: Kona 6061 Aluminum Butted, Fork: Kona Project Two Aluminum Disc, Wheels: WTB ST i19 700c, Crankset: Shimano Sora, Drivetrain: Shimano Sora 9spd, Brakes: TRP Spyre C 160mm front / 160mm rear rotor, Seat Post: Kona Thumb w/Offset, Cockpit: Kona Road Bar/stem, Front Tire: WTB Riddler Comp 700x37c, Rear tire: WTB Riddler Comp 700x37c, Saddle: Kona Road" }
    let(:bike_params) do
      {
        b_param_id_token: "",
        cycle_type: "tall-bike",
        serial_number: "example serial",
        manufacturer_id: manufacturer.slug,
        manufacturer_other: "",
        year: "2016",
        frame_model: extra_long_string,
        primary_frame_color_id: color.id.to_s,
        secondary_frame_color_id: "",
        tertiary_frame_color_id: "",
        owner_email: "something@stuff.com",
        phone: "312.379.9513",
        date_stolen: Time.current.to_i
      }
    end
    before { expect(BParam.all.count).to eq 0 }
    context "successful creation" do
      include_context :geocoder_real
      let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["organization_stolen_message"], search_radius_miles: search_radius_miles) }
      let!(:organization_default_location) { FactoryBot.create(:location, :with_address_record, address_in: :chicago, organization: organization) }
      let(:organization_stolen_message) { OrganizationStolenMessage.where(organization_id: organization.id).first_or_create }
      let(:organization_stolen_message_attrs) { {is_enabled: true, kind: "area", body: "Something cool", search_radius_miles: search_radius_miles} }
      let(:search_radius_miles) { 5 }
      before { organization_stolen_message.update(organization_stolen_message_attrs) }
      def expect_created_stolen_bike(bike_params: nil, stolen_params: {})
        bike_user = FactoryBot.create(:user_confirmed, email: "something@stuff.com")
        VCR.use_cassette("bikes_controller-create-stolen-chicago", match_requests_on: [:method]) do
          expect(organization_stolen_message.reload.search_radius_miles).to eq search_radius_miles
          expect(organization_stolen_message.is_enabled).to be_truthy
          bb_data = {bike: {rear_wheel_bsd: wheel_size.iso_bsd.to_s}, components: []}.as_json
          # We need to call clean_params on the BParam after bikebook update, so that
          # the foreign keys are assigned correctly. This is how we test that we're
          # This is also where we're testing bikebook assignment
          expect_any_instance_of(Integrations::BikeBook).to receive(:get_model) { bb_data }
          ActionMailer::Base.deliveries = []
          Sidekiq::Job.clear_all
          expect {
            Sidekiq::Testing.inline! do
              # Test that we can still pass show_address - because API backward compatibility
              post base_url, params: {bike: bike_params, stolen_record: stolen_params}
            end
          }.to change(Bike, :count).by(1)
          expect(flash[:success]).to be_present
          expect(BParam.all.count).to eq 0
          expect(ActionMailer::Base.deliveries.count).to eq 1
          bike = Bike.last
          bike_params.except(:manufacturer_id, :phone, :date_stolen).each { |k, v| expect(bike.send(k).to_s).to eq v.to_s }
          expect(bike.manufacturer).to eq manufacturer
          expect(bike.status).to eq "status_stolen"
          bike_user.reload
          expect(bike.current_stolen_record.phone).to eq "3123799513"
          expect(bike_user.phone).to eq "3123799513"
          expect(bike.frame_model).to eq extra_long_string # People seem to like putting extra long strings into the frame_model field, so deal with it
          expect(bike.title_string.length).to be < 160 # Because the full frame_model makes things stupid
          expect(bike.current_ownership.status).to eq "status_stolen"
          stolen_record = bike.current_stolen_record
          chicago_stolen_params.except(:state_id).each { |k, v| expect(stolen_record.send(k).to_s).to eq v.to_s }
        end
      end
      it "creates a bike and doesn't create a b_param" do
        expect(organization_stolen_message.reload.is_enabled).to be_truthy
        expect(OrganizationStolenMessage.for_coordinates([41.9, -87.68])&.id).to eq organization_stolen_message.id
        expect_created_stolen_bike(bike_params: bike_params, stolen_params: chicago_stolen_params.merge(show_address: true))
        expect(organization_stolen_message.reload.stolen_records.count).to eq 1
      end
      context "outside of area" do
        let!(:organization_default_location) { FactoryBot.create(:location, :with_address_record, address_in: :new_york, organization: organization) }
        it "doesn't assign organization_stolen_message" do
          expect(organization_stolen_message.reload.longitude).to be_within(2).of(-74)
          expect(organization_stolen_message.reload.search_radius_miles).to eq 5
          expect(OrganizationStolenMessage.for_coordinates([41.9, -87.68])&.id).to be_blank
          expect_created_stolen_bike(bike_params: bike_params, stolen_params: chicago_stolen_params.merge(show_address: true))
          expect(organization_stolen_message.reload.stolen_records.count).to eq 0
        end
        context "association message" do
          let(:organization_stolen_message_attrs) { {is_enabled: true, kind: "association", body: "Something cool", search_radius_miles: search_radius_miles} }
          it "it assigns organization_stolen_message", :flaky do
            expect(organization_stolen_message.reload.kind).to eq "association"
            expect_created_stolen_bike(bike_params: bike_params.merge(creation_organization_id: organization.id), stolen_params: chicago_stolen_params.merge(show_address: true))
            bike = Bike.last
            expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
            expect(bike.current_stolen_record).to be_present
            expect(OrganizationStolenMessage.for_coordinates([41.9, -87.68])&.id).to be_blank
            expect(OrganizationStolenMessage.for_stolen_record(bike.current_stolen_record)&.id).to eq organization_stolen_message.id
            expect(organization_stolen_message.reload.stolen_records.count).to eq 1
          end
        end
      end
    end
    context "failure" do
      it "assigns a bike and a stolen record with the attrs passed" do
        expect {
          post base_url, params: {bike: bike_params.except(:manufacturer_id), stolen_record: chicago_stolen_params}
        }.to change(Bike, :count).by(0)
        expect(BParam.all.count).to eq 1
        expect(BParam.last.bike_errors.to_s).to match(/manufacturer/i)
        bike = assigns(:bike)
        expect(bike).to match_hash_indifferently bike_params.except(:manufacturer_id, :phone)
        expect(bike.status).to eq "status_stolen"
        # we retain the stolen record attrs, test that they are assigned correctly too
        expect(bike.stolen_records.first).to match_hash_indifferently chicago_stolen_params
      end
    end
  end
  context "no existing b_param, impounded" do
    let(:bike_params) { basic_bike_params }
    context "impound_record" do
      include_context :geocoder_real
      let(:impound_params) do
        {
          impounded_at_with_timezone: (Time.current - 1.day).utc,
          timezone: "UTC",
          impounded_description: "Cool description",
          address_record_attributes: {
            country_id: country.id,
            street: "2459 West Division Street",
            city: "Chicago",
            postal_code: "60622",
            region_record_id: state.id
          }
        }
      end
      it "creates a new ownership and impound_record" do
        VCR.use_cassette("bikes_controller-create-impound-chicago", match_requests_on: [:method]) do
          expect {
            post base_url, params: {bike: bike_params, impound_record: impound_params}
            expect(assigns(:bike).errors&.full_messages).to_not be_present
          }.to change(Ownership, :count).by 1
          new_bike = Bike.last
          expect(new_bike).to be_present
          expect(new_bike.authorized?(current_user)).to be_truthy
          expect(new_bike.current_ownership.origin).to eq "impound_process"
          expect(new_bike.current_ownership.organization&.id).to be_blank
          expect(new_bike.current_ownership.creator&.id).to eq current_user.id
          expect(new_bike.status).to eq "status_impounded"
          expect(new_bike.status_humanized).to eq "found"
          expect(new_bike.current_ownership.status).to eq "status_impounded" # Make sure this status matches
          expect(new_bike).to match_hash_indifferently testable_bike_params
          expect(ImpoundRecord.where(bike_id: new_bike.id).count).to eq 1
          impound_record = ImpoundRecord.where(bike_id: new_bike.id).first
          expect(new_bike.current_impound_record&.id).to eq impound_record.id
          expect(impound_record.kind).to eq "found"
          expect(impound_record.impounded_description).to eq "Cool description"
          expect(impound_record.address_record).to be_present
          expect(impound_record.address_record).to have_attributes(
            street: "2459 West Division Street",
            city: "Chicago",
            kind: "impounded_from"
          )
          expect(impound_record.impounded_at.to_i).to be_within(1).of(Time.current.yesterday.to_i)
          expect(impound_record.send(:calculated_unregistered_bike?)).to be_truthy
          expect(impound_record.unregistered_bike?).to be_truthy

          ownership = new_bike.current_ownership
          expect(ownership.claimed?).to be_truthy
          expect(ownership.send_email).to be_falsey
          expect(ownership.self_made?).to be_truthy
          expect(ownership.impound_record_id).to eq impound_record.id
        end
      end
      context "failure" do
        it "assigns a bike and a impound record with the attrs passed" do
          VCR.use_cassette("bikes_controller-create-impound-chicago", match_requests_on: [:method]) do
            expect {
              post base_url, params: {bike: bike_params.except(:manufacturer_id), impound_record: impound_params}
            }.to change(Bike, :count).by(0)
            expect(BParam.all.count).to eq 1
            expect(BParam.last.bike_errors.to_s).to match(/manufacturer/i)
            bike = assigns(:bike)
            expect(bike).to match_hash_indifferently bike_params.except(:manufacturer_id, :phone)
            expect(bike.status).to eq "status_impounded"
            # we retain the impound record attrs, test that they are assigned correctly too
            impound_record = bike.impound_records.first
            expect(impound_record.impounded_description).to eq "Cool description"
            expect(impound_record.address_record).to be_present
            expect(impound_record.address_record.street).to eq "2459 West Division Street"
          end
        end
      end
    end
  end
  context "no existing b_param, reg_address, top_level_propulsion_type" do
    let!(:organization) { FactoryBot.create(:organization_with_organization_features, :in_los_angeles, :with_auto_user, enabled_feature_slugs: %w[reg_address reg_organization_affiliation]) }
    let(:bike_params) do
      {
        b_param_id_token: "",
        creation_organization_id: organization.id.to_s,
        cycle_type: "recumbent",
        serial_number: "141212",
        made_without_serial: false,
        manufacturer_id: manufacturer.slug.to_s,
        manufacturer_other: "",
        year: "2021",
        frame_model: "purple rain",
        primary_frame_color_id: "7",
        secondary_frame_color_id: "",
        tertiary_frame_color_id: "",
        organization_affiliation: "community_member",
        owner_email: current_user.email
      }
    end

    include_context :geocoder_real
    it "does not have address, has association", :flaky do
      Sidekiq::Job.clear_all
      Sidekiq::Testing.inline! do
        # TODO: Fix Geocoder requests, remove stub and uncomment VCR
        allow(GeocodeHelper).to receive(:assignable_address_hash_for).and_return({})
        # VCR.use_cassette("bikes_controller-create-reg_address_blank", match_requests_on: [:method]) do
        expect {
          post base_url, params: {bike: bike_params.merge(cycle_type: "non-e-scooter")}
        }.to change(Bike, :count).by(1)
        # end
      end
      expect(flash[:success]).to be_present
      new_bike = Bike.last
      expect(new_bike).to match_hash_indifferently testable_bike_params.merge(cycle_type: "non-e-scooter")
      expect(new_bike.manufacturer).to eq manufacturer
      expect(new_bike.user_id).to eq current_user.id
      expect(new_bike.ownerships.count).to eq 1
      expect(new_bike.current_ownership.self_made?).to be_truthy

      ownership = new_bike.current_ownership
      expect(ownership.origin).to eq "web"
      expect(ownership.creator_id).to eq current_user.id
      expect(ownership.registration_info).to eq({"organization_affiliation_#{organization.id}" => "community_member", "ip_address" => "127.0.0.1"})
      # It registers with the organization address
      expect(BikeServices::CalculateLocation.registration_address_source(new_bike)).to eq "initial_creation"
      address_attrs = {city: "Los Angeles", country_id: Country.united_states_id, region_record_id: organization.default_address_record.region_record_id, kind: "ownership", latitude: nil, longitude: nil, postal_code: nil}
      expect(new_bike.address_record).to match_hash_indifferently(address_attrs)
      # Because the address is the same as the organization
      expect(new_bike.valid_mailing_address?).to be_falsey
    end
    context "with address_record_attributes" do
      let!(:california) { FactoryBot.create(:state_california) }
      let(:address_record_attributes) { {street: "1400 32nd St", city: "Oakland", postal_code: "94608", region_record_id: california.id} }
      let(:target_address_record_attributes) do
        address_record_attributes.merge(kind: "ownership", country_id: Country.united_states_id)
      end
      let(:target_address_string) { "1400 32nd St, Oakland, CA 94608" }
      it "creates with address", :flaky do
        expect(current_user.reload.to_coordinates.compact).to eq([])
        expect(current_user.user_registration_organizations.count).to eq 0
        VCR.use_cassette("bikes_controller-create-reg_address", match_requests_on: [:method]) do
          expect(BikeServices::Displayer.display_edit_address_fields?(Bike.new, current_user)).to be_truthy
          organization.reload
          expect(organization.location_latitude.to_i).to eq 34
          expect(organization.default_location).to be_present
          expect(current_user.organization_roles.pluck(:id)).to eq([]) # sanity check
          Sidekiq::Job.clear_all
          Sidekiq::Testing.inline! do
            expect {
              post base_url, params: {
                bike: bike_params.merge(address_record_attributes:),
                propulsion_type_motorized: true,
                propulsion_type_throttle: false,
                propulsion_type_pedal_assist: false
              }
            }.to change(Bike, :count).by(1)
          end
          expect(flash[:success]).to be_present
          new_bike = Bike.last

          # Make sure things render
          expect(response).to redirect_to(edit_bike_path(new_bike))
          get edit_bike_path(new_bike) # Should make the bike claim
          expect(response).to render_template("bikes_edit/bike_details")

          new_bike.reload
          expect(new_bike.b_params.count).to eq 0
          expect(testable_bike_params.keys.count).to be > 10
          expect(new_bike).to match_hash_indifferently testable_bike_params
          expect(new_bike.manufacturer).to eq manufacturer
          expect(new_bike.user_id).to eq current_user.id
          expect(new_bike.ownerships.count).to eq 1
          expect(new_bike.current_ownership.self_made?).to be_truthy
          expect(new_bike.propulsion_type).to eq "pedal-assist"
          expect(new_bike.address_record).to match_hash_indifferently target_address_record_attributes
          expect(new_bike.current_ownership.address_record_id).to eq new_bike.address_record_id
          expect(new_bike.to_coordinates.map(&:round)).to eq([38, -122])

          ownership = new_bike.current_ownership
          expect(ownership.origin).to eq "web"
          expect(ownership.creator_id).to eq current_user.id
          reg_hash = address_record_attributes
            .merge("organization_affiliation_#{organization.id}" => "community_member", "ip_address" => "127.0.0.1")
          expect(ownership.registration_info).to match_hash_indifferently reg_hash

          expect(new_bike.formatted_address_string(visible_attribute: :street)).to eq target_address_string
          expect(new_bike.valid_mailing_address?).to be_truthy
          expect(current_user.reload.formatted_address_string(visible_attribute: :street)).to eq target_address_string

          expect(BikeServices::Displayer.display_edit_address_fields?(new_bike, current_user)).to be_falsey
          expect(current_user.user_registration_organizations.pluck(:organization_id)).to eq([organization.id])
          user_registration_organization = current_user.user_registration_organizations.first
          expect(user_registration_organization.all_bikes?).to be_truthy
          expect(user_registration_organization.can_edit_claimed).to be_truthy
        end
      end
    end
  end
  context "no existing b_param, bike_code" do
    let(:organization) { FactoryBot.create(:organization_with_auto_user) }
    let(:bike) { FactoryBot.create(:bike) }
    let!(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: organization, bike: bike, code: "ED00001") }
    # Created the same way that organizations controller creates a b_param
    let(:b_param) { BParam.create(creator_id: organization.auto_user.id, params: {creation_organization_id: organization.id, embeded: true, bike: {}}) }
    let(:bike_params) do
      {
        b_param_id_token: b_param.id_token,
        embeded: "true",
        creation_organization_id: organization.id,
        embeded_extended: true,
        serial_number: "example serial",
        manufacturer_id: manufacturer.slug,
        manufacturer_other: "",
        primary_frame_color_id: color.id.to_s,
        secondary_frame_color_id: "",
        tertiary_frame_color_id: "",
        owner_email: "something@stuff.COM   ",
        phone: "312.379.9513",
        student_id: " ",
        cycle_type: "personal-mobility",
        bike_code: "ed001"
      }
    end
    it "creates and adds the bike code", :flaky do
      b_param.reload
      expect(b_param.created_bike_id).to be_blank
      expect {
        post base_url, params: {bike: bike_params}
      }.to change(Bike, :count).by(1)
      expect(flash[:success]).to be_present

      b_param.reload
      expect(b_param.bike_sticker_code).to eq "ed001"
      expect(b_param.created_bike_id).to be_present
      new_bike = b_param.created_bike
      expect(new_bike.owner_email).to eq "something@stuff.com"
      expect(new_bike.user).to be_blank
      expect(new_bike.status).to eq "status_with_owner"
      expect(new_bike.phone).to eq "3123799513"
      expect(new_bike.student_id).to eq nil
      expect(new_bike.cycle_type).to eq "personal-mobility"
      expect(new_bike.motorized?).to be_truthy
      expect(new_bike.latitude).to be_present # Because IP address!
      expect(new_bike.longitude).to be_present

      expect(new_bike.current_ownership.organization&.id).to eq organization.id
      expect(new_bike.current_ownership.origin).to eq "embed_extended"

      expect(new_bike.bike_stickers.pluck(:id)).to eq([bike_sticker.id])
      expect(bike_sticker.reload.claimed?).to be_truthy
      expect(bike_sticker.bike&.id).to eq new_bike.id
      expect(bike_sticker.bike_sticker_updates.count).to eq 1
    end
    context "no organization" do
      it "registers" do
        b_param.reload
        expect(b_param.created_bike_id).to be_blank
        expect {
          post base_url, params: {bike: bike_params.merge(creation_organization_id: nil)}
        }.to change(Bike, :count).by(1)
        expect(flash[:success]).to be_present

        b_param.reload
        expect(b_param.bike_sticker_code).to eq "ed001"
        expect(b_param.created_bike_id).to be_present
        new_bike = b_param.created_bike
        expect(new_bike.owner_email).to eq "something@stuff.com"
        expect(new_bike.user).to be_blank
        expect(new_bike.status).to eq "status_with_owner"
        expect(new_bike.phone).to eq "3123799513"
        expect(new_bike.student_id).to eq nil

        expect(new_bike.current_ownership.organization&.id).to be_blank
        expect(new_bike.current_ownership.origin).to eq "embed_extended"

        expect(new_bike.bike_stickers.pluck(:id)).to eq([])
        expect(bike_sticker.bike&.id).to eq bike.id
        expect(bike_sticker.bike_sticker_updates.count).to eq 0
      end
    end
  end
  context "existing b_param, no bike" do
    let(:bike_params) do
      basic_bike_params.merge(cycle_type: "cargo-rear",
        serial_number: "example serial",
        secondary_frame_color_id: "",
        tertiary_frame_color_id: "",
        owner_email: "something@stuff.com")
    end
    let(:b_param) { BParam.create(params: {"bike" => bike_params.as_json}, origin: "embed_partial") }
    before do
      expect(b_param.partial_registration?).to be_truthy
      bb_data = {bike: {}}
      # We need to call clean_params on the BParam after bikebook update, so that
      # the foreign keys are assigned correctly.
      # This is also where we're testing bikebook assignment
      expect_any_instance_of(Integrations::BikeBook).to receive(:get_model) { bb_data }
      expect(state).to be_present
    end
    let!(:target_address) { {street: "212 Main St", city: "Chicago", region: "IL", postal_code: "60647", kind: "ownership"} }
    let(:passed_bike_params) do
      {
        manufacturer_id: manufacturer.slug,
        b_param_id_token: b_param.id_token,
        address_record_attributes: {
          street: "212 Main St",
          city: "Chicago",
          region_string: "IL",
          postal_code: "60647"
        },
        extra_registration_number: " ",
        organization_affiliation: "student",
        student_id: "999888",
        phone: "1 (888) 777 - 6666"
      }
    end
    let(:target_registration_info) do
      {street: "212 Main St", city: "Chicago", region_string: "IL", postal_code: "60647", phone: "18887776666",
       organization_affiliation: "student", student_id: "999888", ip_address: "127.0.0.1"}
    end
    it "creates the bike and does the updated address thing" do
      expect {
        post base_url, params: {bike: passed_bike_params}
      }.to change(Bike, :count).by(1)
      expect(flash[:success]).to be_present
      new_bike = Bike.last
      b_param.reload
      expect(b_param.created_bike_id).to eq new_bike.id
      expect(new_bike).to match_hash_indifferently testable_bike_params
      expect(new_bike.manufacturer).to eq manufacturer
      expect(new_bike.current_ownership.origin).to eq "embed_partial"
      expect(new_bike.current_ownership.creator).to eq new_bike.creator
      # Pulled from BParam. Doesn't happen in real life, but :shrug:
      expect(new_bike.cycle_type).to eq "cargo-rear"
      expect(new_bike.serial_number).to eq "example serial"

      expect(new_bike.address_record).to match_hash_indifferently target_address
      expect(new_bike.current_ownership.address_record).to be_present
      expect(new_bike.extra_registration_number).to be_nil
      expect(new_bike.organization_affiliation).to eq "student"
      expect(new_bike.phone).to eq "18887776666"
      expect(new_bike.student_id).to eq "999888"
      expect(new_bike.registration_info).to match_hash_indifferently(target_registration_info)

      current_user.reload
      expect(new_bike.owner).to eq current_user # NOTE: not bike user
      expect(current_user.phone).to be_nil # Because the phone doesn't set for the creator
    end
  end
  context "existing b_param, created bike" do
    let(:bike) { FactoryBot.create(:bike) }
    it "redirects to the bike" do
      b_param = BParam.create(params: {bike: {}}, created_bike_id: bike.id, creator_id: current_user.id)
      expect(b_param.created_bike).to be_present
      post base_url, params: {bike: {b_param_id_token: b_param.id_token}}
      expect(response).to redirect_to(edit_bike_url(bike.id))
    end
  end
end
