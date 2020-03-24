require "rails_helper"

RSpec.describe Api::V1::BikesController, type: :controller do
  describe "index" do
    it "loads the page and have the correct headers" do
      FactoryBot.create(:bike)
      get :index, params: { format: :json }
      expect(response.code).to eq("200")
    end
  end

  describe "stolen_ids" do
    it "returns correct code if no org" do
      FactoryBot.create(:color)
      get :stolen_ids, params: { format: :json }
      expect(response.code).to eq("401")
    end

    it "should return an array of ids" do
      _bike = FactoryBot.create(:bike)
      _stole1 = FactoryBot.create(:stolen_record)
      stole2 = FactoryBot.create(:stolen_record, approved: true)
      organization = FactoryBot.create(:organization)
      user = FactoryBot.create(:user)
      FactoryBot.create(:membership_claimed, user: user, organization: organization)
      options = { stolen: true, organization_slug: organization.slug, access_token: organization.access_token }
      get :stolen_ids, params: options.as_json
      expect(response.code).to eq("200")
      bikes = JSON.parse(response.body)["bikes"]
      expect(bikes.count).to eq(1)
      expect(bikes.first).to eq(stole2.bike.id)
    end
  end

  describe "show" do
    it "loads the page" do
      bike = FactoryBot.create(:bike)
      get :show, params: { id: bike.id, format: :json }
      expect(response.code).to eq("200")
    end
  end

  describe "create" do
    before do
      FactoryBot.create(:wheel_size, iso_bsd: 559)
      FactoryBot.create(:ctype, name: "wheel")
      FactoryBot.create(:ctype, name: "headset")
    end
    context "pos_integrator rear_gear_type_slug error" do
      let(:auto_user) { FactoryBot.create(:organization_auto_user) }
      let(:organization) { auto_user.organizations.first }
      let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Specialized") }
      let(:black) { FactoryBot.create(:color, name: "Black") }
      let(:red) { FactoryBot.create(:color, name: "Red") }
      let(:bike_hash) do
        {
          organization_slug: organization.slug,
          access_token: organization.access_token,
          bike: {
            owner_email: "example@gmail.com",
            serial_number: "SSOMESERIAL",
            manufacturer: "Specialized",
            frame_model: "Diverge Elite DSW (58)",
            cycle_type: "trail-behind",
            color: "Black/Red",
            send_email: true,
            frame_size: "58",
            frame_size_unit: "cm",
            year: 2016,
            rear_wheel_size: nil,
            rear_gear_type_slug: nil,
            handlebar_type_slug: nil,
            frame_material_slug: "",
            description: "Diverge Elite DSW (58)",
            is_pos: true,
            is_new: true,
            is_bulk: true,
          },
        }
      end
      before do
        expect([black, red, manufacturer].size).to eq 3
      end
      it "creates a bike and does not duplicate" do
        expect do
          post :create, params: bike_hash.as_json
        end.to change(Ownership, :count).by(1)

        expect(response.code).to eq("200")
        bike = Bike.where(serial_number: "SSOMESERIAL").first
        expect(bike.manufacturer).to eq manufacturer
        expect(bike.frame_model).to eq "Diverge Elite DSW (58)"
        expect(bike.frame_size).to eq "58cm"
        expect(bike.frame_size_unit).to eq "cm"
        expect(bike.primary_frame_color).to eq black
        expect(bike.paint_description).to eq "Black/Red"
        creation_state = bike.creation_state
        expect([creation_state.is_pos, creation_state.is_new, creation_state.is_bulk]).to eq([true, true, true])
        expect(creation_state.organization).to eq organization
        expect(creation_state.creator).to eq bike.creator
        expect(creation_state.origin).to eq "api_v1"
        expect do
          updated_hash = bike_hash.merge(bike: bike_hash[:bike].merge(no_duplicate: true))
          post :create, params: updated_hash.as_json
        end.to change(Ownership, :count).by 0
      end

      context "new pos_integrator format" do
        # We're switching to use numeric id rather than slug, because the slugs change :(
        it "creates correctly" do
          expect do
            post :create, params: bike_hash.merge(organization_slug: organization.id).as_json
          end.to change(Ownership, :count).by(1)

          expect(response.code).to eq("200")
          bike = Bike.where(serial_number: "SSOMESERIAL").first
          expect(bike.manufacturer).to eq manufacturer
          expect(bike.frame_model).to eq "Diverge Elite DSW (58)"
          expect(bike.frame_size).to eq "58cm"
          expect(bike.frame_size_unit).to eq "cm"
          expect(bike.primary_frame_color).to eq black
          expect(bike.paint_description).to eq "Black/Red"
          creation_state = bike.creation_state
          expect([creation_state.is_pos, creation_state.is_new, creation_state.is_bulk]).to eq([true, true, true])
          expect(creation_state.organization).to eq organization
          expect(creation_state.creator).to eq bike.creator
          expect(creation_state.origin).to eq "api_v1"
          expect(creation_state.pos_kind).to eq "lightspeed_pos"
          expect do
            updated_hash = bike_hash.merge(bike: bike_hash[:bike].merge(no_duplicate: true))
            post :create, params: updated_hash.as_json
          end.to change(Ownership, :count).by 0
        end
      end
    end

    context "legacy tests" do
      before :each do
        @organization = FactoryBot.create(:organization)
        user = FactoryBot.create(:user)
        FactoryBot.create(:membership_claimed, user: user, organization: @organization)
        @organization.save
      end

      it "returns correct code if not logged in" do
        c = FactoryBot.create(:color)
        post :create, params: { bike: { serial_number: "69", color: c.name } }
        expect(response.code).to eq("401")
      end

      it "returns correct code if bike has errors" do
        c = FactoryBot.create(:color)
        post :create, params: { bike: { serial_number: "69", color: c.name }, organization_slug: @organization.slug, access_token: @organization.access_token }
        expect(response.code).to eq("422")
      end

      it "emails us if it can't create a record" do
        c = FactoryBot.create(:color)
        expect do
          post :create, params: { bike: { serial_number: "69", color: c.name }, organization_slug: @organization.slug, access_token: @organization.access_token }
        end.to change(Feedback, :count).by(1)
      end

      it "creates a record and reset example" do
        manufacturer = FactoryBot.create(:manufacturer)
        rear_gear_type = FactoryBot.create(:rear_gear_type)
        front_gear_type = FactoryBot.create(:front_gear_type)
        f_count = Feedback.count
        bike_attrs = {
          serial_number: "69 non-example",
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: "true",
          rear_wheel_bsd: 559,
          color: FactoryBot.create(:color).name,
          example: true,
          year: "1969",
          owner_email: "fun_times@examples.com",
          frame_model: "Tricruiser Tricycle",
          cycle_type: "trail-behind",
          send_email: true,
          frame_size: "56cm",
          frame_size_unit: nil,
          rear_gear_type_slug: rear_gear_type.slug,
          front_gear_type_slug: front_gear_type.slug,
          handlebar_type_slug: "forward",
          registered_new: true,
        }
        components = [
          {
            manufacturer: manufacturer.name,
            year: "1999",
            component_type: "Headset",
            cgroup: "Frame and fork",
            description: "yeah yay!",
            serial_number: "69",
            model_name: "Richie rich",
          },
          {
            manufacturer: "BLUE TEETH",
            front_or_rear: "Both",
            cgroup: "Wheels",
            component_type: "wheel",
          },
        ]
        photos = [
          "http://i.imgur.com/lybYl1l.jpg",
          "http://i.imgur.com/3BGQeJh.jpg",
        ]
        expect_any_instance_of(OwnershipCreator).to receive(:send_notification_email)
        expect do
          post :create, params: { bike: bike_attrs, organization_slug: @organization.slug, access_token: @organization.access_token, components: components, photos: photos }
        end.to change(Ownership, :count).by(1)
        expect(response.code).to eq("200")
        bike = Bike.where(serial_number: "69 non-example").first
        expect(bike.example).to be_falsey
        expect(bike.creation_organization_id).to eq(@organization.id)
        expect(bike.year).to eq(1969)
        expect(bike.components.count).to eq(3)
        expect(bike.creation_state.organization).to eq @organization
        component = bike.components.where(serial_number: "69").first
        expect(component.description).to eq("yeah yay!")
        expect(component.ctype.slug).to eq("headset")
        expect(component.year).to eq(1999)
        expect(component.manufacturer_id).to eq(manufacturer.id)
        expect(component.cmodel_name).to eq("Richie rich")
        expect(bike.public_images.count).to eq(2)
        expect(f_count).to eq(Feedback.count)
        skipped = %w(send_email frame_size_unit rear_wheel_bsd color example rear_gear_type_slug front_gear_type_slug handlebar_type_slug)
        bike_attrs.except(*skipped.map(&:to_sym)).each do |attr_name, value|
          pp attr_name unless bike.send(attr_name).to_s == value.to_s
          expect(bike.send(attr_name).to_s).to eq value.to_s
        end
        expect(bike.frame_size_unit).to eq "cm"
        expect(bike.rear_wheel_size.iso_bsd).to eq bike_attrs[:rear_wheel_bsd]
        expect(bike.primary_frame_color.name).to eq bike_attrs[:color]
        expect(bike.rear_gear_type.slug).to eq bike_attrs[:rear_gear_type_slug]
        expect(bike.front_gear_type.slug).to eq bike_attrs[:front_gear_type_slug]
        expect(bike.handlebar_type).to eq bike_attrs[:handlebar_type_slug]
        creation_state = bike.creation_state
        expect([creation_state.is_pos, creation_state.is_new, creation_state.is_bulk]).to eq([false, false, false])
        expect(creation_state.organization).to eq @organization
        expect(creation_state.creator).to eq bike.creator
        expect(creation_state.origin).to eq "api_v1"
      end

      it "creates a photos even if one fails" do
        manufacturer = FactoryBot.create(:manufacturer)
        bike_attrs = {
          serial_number: "69 photo-test",
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: "true",
          rear_wheel_bsd: "559",
          color: FactoryBot.create(:color).name,
          example: true,
          year: "1969",
          owner_email: "fun_times@examples.com",
          cycle_type: "wheelchair",
        }
        photos = [
          "http://i.imgur.com/lybYl1l.jpg",
          "http://bikeindex.org/not_actually_a_thing_404_and_shit",
        ]
        post :create, params: { bike: bike_attrs, organization_slug: @organization.slug, access_token: @organization.access_token, photos: photos }
        bike = Bike.where(serial_number: "69 photo-test").first
        expect(bike.public_images.count).to eq(1)
        expect(bike.creation_state.origin).to eq "api_v1"
        expect(bike.creation_state.creator).to eq bike.creator
        expect(bike.creation_state.organization).to eq @organization
        expect(bike.rear_wheel_size.iso_bsd).to eq 559
      end

      include_context :geocoder_real

      it "creates a stolen record" do
        VCR.use_cassette("v1_bikes_create-stolen") do
          manufacturer = FactoryBot.create(:manufacturer)
          @organization.users.first.update_attribute :phone, "123-456-6969"
          FactoryBot.create(:state, abbreviation: "IL", name: "Illinois")
          bike_attrs = {
            serial_number: "69 stolen bike",
            manufacturer_id: manufacturer.id,
            rear_tire_narrow: "true",
            rear_wheel_size: 559,
            primary_frame_color_id: FactoryBot.create(:color).id,
            owner_email: "fun_times@examples.com",
            stolen: "true",
            phone: "9999999",
            cycle_type_slug: "bike",
          }
          stolen_record = {
            date_stolen: "03-01-2013",
            theft_description: "This bike was stolen and that's no fair.",
            country: "US",
            street: "Cortland and Ashland",
            zipcode: "60622",
            state: "IL",
            police_report_number: "99999999",
            police_report_department: "Chicago",
            locking_description: "some locking description",
            lock_defeat_description: "broken in some crazy way",
          }
          expect_any_instance_of(OwnershipCreator).to receive(:send_notification_email)

          expect do
            post :create, params: { bike: bike_attrs, stolen_record: stolen_record, organization_slug: @organization.slug, access_token: @organization.access_token }
          end.to change(Ownership, :count).by(1)
          expect(response.code).to eq("200")
          bike = Bike.unscoped.where(serial_number: "69 stolen bike").first
          expect(bike.creation_state.origin).to eq "api_v1"
          expect(bike.creation_state.creator).to eq bike.creator
          expect(bike.creation_state.organization).to eq @organization
          expect(bike.rear_wheel_size.iso_bsd).to eq 559
          csr = bike.find_current_stolen_record
          expect(csr.display_address).to be_present
          expect(csr.phone).to eq("9999999")
          # No longer support this date format :/
          # expect(csr.date_stolen).to eq(DateTime.strptime("03-01-2013 06", "%m-%d-%Y %H"))
          expect(csr.locking_description).to eq("some locking description")
          expect(csr.lock_defeat_description).to eq("broken in some crazy way")
        end
      end

      it "creates an example bike if the bike is from example, and include all the options" do
        FactoryBot.create(:color, name: "Black")
        org = FactoryBot.create(:organization, name: "Example organization")
        user = FactoryBot.create(:user)
        FactoryBot.create(:membership_claimed, user: user, organization: org)
        manufacturer = FactoryBot.create(:manufacturer)
        org.save
        bike_attrs = {
          serial_number: "69 example bikez",
          cycle_type_slug: "unicycle",
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: "true",
          rear_wheel_size: 559,
          color: "grazeen",
          frame_material_slug: "Steel",
          handlebar_type_slug: "Other",
          description: "something else",
          owner_email: "fun_times@examples.com",
        }
        ActionMailer::Base.deliveries = []
        expect do
          post :create, params: { bike: bike_attrs, organization_slug: org.slug, access_token: org.access_token }
        end.to change(Ownership, :count).by(1)
        EmailOwnershipInvitationWorker.drain
        expect(ActionMailer::Base.deliveries).to eq([])
        expect(response.code).to eq("200")
        bike = Bike.unscoped.where(serial_number: "69 example bikez").first
        expect(bike.creation_state.origin).to eq "api_v1"
        expect(bike.creation_state.organization).to eq org
        expect(bike.example).to be_truthy
        expect(bike.rear_wheel_size.iso_bsd).to eq 559
        expect(bike.paint.name).to eq("grazeen")
        expect(bike.description).to eq("something else")
        expect(bike.frame_material_name).to eq("Steel")
        expect(bike.frame_material).to eq("steel")
        expect(bike.handlebar_type).to eq("other")
        expect(bike.cycle_type).to eq("unicycle")
        expect(bike.cycle_type_name).to eq("Unicycle")
      end

      it "creates a record even if the post is a string" do
        manufacturer = FactoryBot.create(:manufacturer)
        bike_attrs = {
          serial_number: "69 string",
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: "true",
          rear_wheel_bsd: "559",
          color: FactoryBot.create(:color).name,
          owner_email: "jsoned@examples.com",
          cycle_type: "tandem",
        }
        options = { bike: bike_attrs.to_json, organization_slug: @organization.slug, access_token: @organization.access_token }
        ActionMailer::Base.deliveries = []
        expect do
          post :create, params: options
        end.to change(Ownership, :count).by(1)
        EmailOwnershipInvitationWorker.drain
        expect(ActionMailer::Base.deliveries.count).to eq 1
        expect(response.code).to eq("200")
        bike = Bike.unscoped.where(serial_number: "69 string").first
        expect(bike.creation_state.origin).to eq "api_v1"
        expect(bike.creation_state.organization).to eq @organization
      end

      it "does not send an ownership email if it has no_email set" do
        manufacturer = FactoryBot.create(:manufacturer)
        bike = {
          serial_number: "69 string",
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: "true",
          rear_wheel_bsd: "559",
          color: FactoryBot.create(:color).name,
          owner_email: "jsoned@examples.com",
          send_email: "false",
          cycle_type_name: " trailer ",
        }
        options = { bike: bike.to_json, organization_slug: @organization.slug, access_token: @organization.access_token }
        ActionMailer::Base.deliveries = []
        expect do
          post :create, params: options
        end.to change(Ownership, :count).by(1)
        EmailOwnershipInvitationWorker.drain
        expect(ActionMailer::Base.deliveries.count).to eq(0)
        expect(response.code).to eq("200")
        bike = Bike.unscoped.where(serial_number: "69 string").first
        expect(bike.creation_state.origin).to eq "api_v1"
        expect(bike.creation_state.organization).to eq @organization
      end
    end
  end
end
