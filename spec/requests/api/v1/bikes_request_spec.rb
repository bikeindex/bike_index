require "rails_helper"

base_url = "/api/v1/bikes"
RSpec.describe API::V1::BikesController, type: :request do
  describe "index" do
    it "loads the page and have the correct headers" do
      FactoryBot.create(:bike, handlebar_type: "flat")
      get base_url, params: {format: :json}
      bike = json_result["bikes"].first
      expect(bike["id"]).to be_present
      expect(bike["handlebar_type"]).to eq "Flat or riser"
      expect(bike.key?("user_hidden")).to be_falsey
      expect(response.code).to eq("200")
    end
    context "stolen bike" do
      let!(:bike) { FactoryBot.create(:bike, :with_stolen_record) }
      it "returns with public latitude" do
        bike.reload
        expect(bike.fetch_current_stolen_record.latitude_public).to eq(40.71)
        get base_url, params: {format: :json}
        expect(json_result["bikes"].count).to eq 1
        bike_response = json_result["bikes"].first
        expect(bike_response["stolen_record"]["latitude"]).to eq 40.71
        expect(bike_response["stolen_record"]["longitude"]).to eq bike.current_stolen_record.longitude_public
      end
    end
  end

  describe "stolen_ids" do
    it "returns correct code if no org" do
      FactoryBot.create(:color)
      get "#{base_url}/stolen_ids", params: {format: :json}
      expect(response.code).to eq("401")
    end

    it "should return an array of ids" do
      _bike = FactoryBot.create(:bike)
      _stole1 = FactoryBot.create(:stolen_record)
      stole2 = FactoryBot.create(:stolen_record, approved: true)
      organization = FactoryBot.create(:organization)
      user = FactoryBot.create(:user)
      FactoryBot.create(:organization_role_claimed, user: user, organization: organization)
      options = {stolen: true, organization_slug: organization.slug, access_token: organization.access_token}
      get "#{base_url}/stolen_ids", params: options.as_json
      expect(response.code).to eq("200")
      bikes = JSON.parse(response.body)["bikes"]
      expect(bikes.count).to eq(1)
      expect(bikes.first).to eq(stole2.bike.id)
    end
  end

  describe "show" do
    it "loads the page" do
      bike = FactoryBot.create(:bike)
      get "#{base_url}/#{bike.id}", params: {format: :json}
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
      let(:black) { Color.black }
      let(:red) { FactoryBot.create(:color, name: "Red") }
      let(:bike_hash) do
        {
          organization_slug: organization.slug,
          access_token: organization.access_token,
          bike: {
            no_duplicate: true,
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
            is_bulk: false
          }
        }
      end
      before do
        expect([black, red, manufacturer].size).to eq 3
        expect(bike_hash).to be_present # make sure the things are created before we clear the queues
        ActionMailer::Base.deliveries = []
        Sidekiq::Job.clear_all
      end

      def expect_matching_created_bike(created_bike)
        expect(created_bike.manufacturer).to eq manufacturer
        expect(created_bike.frame_model).to eq "Diverge Elite DSW (58)"
        expect(created_bike.frame_size).to eq "58cm"
        expect(created_bike.frame_size_unit).to eq "cm"
        expect(created_bike.primary_frame_color).to eq black
        expect(created_bike.paint_description).to eq "Black/Red"
        expect(created_bike.ownerships.count).to eq 1
        ownership = created_bike.current_ownership
        expect([ownership.pos?, ownership.is_new, ownership.bulk?]).to eq([true, true, false])
        expect(ownership.organization).to eq organization
        expect(ownership.creator).to eq created_bike.creator
        expect(ownership.origin).to eq "api_v1"
        expect(ownership.pos_kind).to eq "lightspeed_pos"
        expect(ownership.is_new).to be_truthy
      end

      it "creates a bike and does not duplicate", :flaky do
        expect {
          post base_url, params: bike_hash.as_json
        }.to change(Ownership, :count).by(1)

        expect(response.code).to eq("200")
        bike = Bike.where(serial_number: "SSOMESERIAL").first
        expect_matching_created_bike(bike)
        og_ownership = bike.current_ownership

        expect {
          post base_url, params: bike_hash.as_json
        }.to change(Ownership, :count).by 0

        bike.reload
        expect(bike.current_ownership).to eq og_ownership
        expect(bike.ownerships.count).to eq 1

        Sidekiq::Job.drain_all # Not wrapping both in drain_all, because
        expect(ActionMailer::Base.deliveries.count).to eq 1
        expect(ActionMailer::Base.deliveries.last.subject).to eq "Confirm your #{organization.name} Bike Index registration"
      end

      context "new pos_integrator format" do
        # We're switching to use numeric id rather than slug, because the slugs change :(
        it "creates correctly", :flaky do
          Sidekiq::Testing.inline! do
            expect {
              post base_url, params: bike_hash.merge(organization_slug: organization.id).as_json
            }.to change(Ownership, :count).by(1)
          end

          expect(response.code).to eq("200")
          bike = Bike.where(serial_number: "SSOMESERIAL").first
          expect_matching_created_bike(bike)
          expect(bike.credibility_score).to eq 100

          expect {
            # And do it a couple more times
            post base_url, params: bike_hash
            post base_url, params: bike_hash
          }.to change(Ownership, :count).by 0

          Sidekiq::Job.drain_all
          expect(ActionMailer::Base.deliveries.count).to eq 1
          expect(ActionMailer::Base.deliveries.last.subject).to eq "Confirm your #{organization.name} Bike Index registration"
        end
        context "with risky email" do
          it "registers but doesn't send an email", :flaky do
            expect {
              post base_url, params: bike_hash.merge(bike: bike_hash[:bike].merge(owner_email: "carolyn@hotmail.co")).as_json
            }.to change(Ownership, :count).by(1)

            expect(response.code).to eq("200")
            bike = Bike.where(serial_number: "SSOMESERIAL").first
            expect_matching_created_bike(bike)

            Sidekiq::Job.drain_all
            expect(ActionMailer::Base.deliveries.count).to eq 0
          end
        end
        context "with bike_sticker and phone" do
          let(:primary_organization) { FactoryBot.create(:organization) }
          let!(:bike_sticker) { FactoryBot.create(:bike_sticker, code: "CAL09999", organization: primary_organization) }
          let(:post_hash) do
            bike_hash_nested = bike_hash[:bike].merge(bike_sticker: "CAL 00 09 99 9", phone: "CELL888 777 - 6666")
            bike_hash.merge(organization_slug: organization.id, bike: bike_hash_nested)
          end
          it "creates and adds sticker", :flaky do
            expect(bike_sticker.bike_sticker_updates.count).to eq 0
            Sidekiq::Testing.inline! do
              expect {
                post base_url, params: post_hash.as_json
              }.to change(Ownership, :count).by(1)
            end
            expect(response.code).to eq("200")
            expect(Bike.where(serial_number: "SSOMESERIAL").count).to eq 1
            bike = Bike.where(serial_number: "SSOMESERIAL").first
            expect_matching_created_bike(bike)
            expect(bike.phone).to eq "CELL8887776666"

            Sidekiq::Job.drain_all
            expect(ActionMailer::Base.deliveries.count).to eq 1
            expect(ActionMailer::Base.deliveries.last.subject).to eq "Confirm your #{organization.name} Bike Index registration"

            expect(response.code).to eq("200")
            bike = Bike.where(serial_number: "SSOMESERIAL").first
            expect_matching_created_bike(bike)

            bike_sticker.reload
            expect(bike_sticker.bike_id).to eq bike.id
            expect(bike_sticker.claimed?).to be_truthy
            expect(bike_sticker.organization_id).to eq primary_organization.id
            expect(bike_sticker.secondary_organization_id).to eq organization.id
            expect(bike_sticker.bike_sticker_updates.count).to eq 1
            bike_sticker_update = bike_sticker.bike_sticker_updates.first
            expect(bike_sticker_update.organization_id).to eq organization.id
            expect(bike_sticker_update.creator_kind).to eq "creator_pos"
          end
        end
      end
    end

    context "legacy tests" do
      before :each do
        @organization = FactoryBot.create(:organization)
        user = FactoryBot.create(:user)
        FactoryBot.create(:organization_role_claimed, user: user, organization: @organization)
        @organization.save
      end

      it "returns correct code if not logged in" do
        c = FactoryBot.create(:color)
        post base_url, params: {bike: {serial_number: "69", color: c.name}}
        expect(response.code).to eq("401")
      end

      it "returns correct code if bike has errors" do
        c = FactoryBot.create(:color)
        post base_url, params: {bike: {serial_number: "69", color: c.name}, organization_slug: @organization.slug, access_token: @organization.access_token}
        expect(response.code).to eq("422")
      end

      it "emails us if it can't create a record" do
        c = FactoryBot.create(:color)
        expect {
          post base_url, params: {bike: {serial_number: "69", color: c.name}, organization_slug: @organization.slug, access_token: @organization.access_token}
        }.to change(Feedback, :count).by(1)
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
          handlebar_type_slug: "forward"
        }
        components = [
          {
            manufacturer: manufacturer.name,
            year: "1999",
            component_type: "Headset",
            cgroup: "Frame and fork",
            description: "yeah yay!",
            serial_number: "69",
            model_name: "Richie rich"
          },
          {
            manufacturer: "BLUE TEETH",
            front_or_rear: "Both",
            cgroup: "Wheels",
            component_type: "wheel"
          }
        ]
        photos = [
          "http://i.imgur.com/lybYl1l.jpg",
          "http://i.imgur.com/3BGQeJh.jpg"
        ]
        ActionMailer::Base.deliveries = []
        Sidekiq::Job.clear_all
        VCR.use_cassette("v1_bikes_create-images", match_requests_on: [:path], re_record_interval: 1.month) do
          Sidekiq::Testing.inline! do
            expect {
              post base_url, params: {bike: bike_attrs, organization_slug: @organization.slug, access_token: @organization.access_token, components: components, photos: photos}
            }.to change(Ownership, :count).by(1)
          end
        end
        # expect(ActionMailer::Base.deliveries.count).to eq 0
        expect(response.code).to eq("200")
        bike = Bike.unscoped.where(serial_number: "69 non-example").first
        expect(bike.example).to be_truthy
        expect(bike.creation_organization_id).to eq(@organization.id)
        expect(bike.year).to eq(1969)
        expect(bike.components.count).to eq(3)
        expect(bike.current_ownership.organization).to eq @organization
        component = bike.components.where(serial_number: "69").first
        expect(component.description).to eq("yeah yay!")
        expect(component.ctype.slug).to eq("headset")
        expect(component.year).to eq(1999)
        expect(component.manufacturer_id).to eq(manufacturer.id)
        expect(component.component_model).to eq("Richie rich")
        expect(bike.public_images.count).to eq(2)
        expect(f_count).to eq(Feedback.count)
        skipped = %w[send_email frame_size_unit rear_wheel_bsd color example rear_gear_type_slug front_gear_type_slug handlebar_type_slug]
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
        ownership = bike.current_ownership
        expect([ownership.pos?, ownership.is_new, ownership.bulk?]).to eq([false, false, false])
        expect(ownership.organization).to eq @organization
        expect(ownership.creator).to eq bike.creator
        expect(ownership.origin).to eq "api_v1"
      end

      it "creates a photos even if one fails", :flaky do
        manufacturer = FactoryBot.create(:manufacturer)
        bike_attrs = {
          serial_number: "69 photo-test",
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: "true",
          rear_wheel_bsd: "559",
          color: FactoryBot.create(:color).name,
          example: false,
          year: "1969",
          owner_email: "fun_times@examples.com",
          cycle_type: "wheelchair"
        }
        photos = [
          "http://i.imgur.com/lybYl1l.jpg",
          "http://bikeindex.org/not_actually_a_thing_404_and_shit"
        ]
        VCR.use_cassette("v1_bikes_create-images2", match_requests_on: [:path], re_record_interval: 1.month) do
          post base_url, params: {bike: bike_attrs, organization_slug: @organization.slug, access_token: @organization.access_token, photos: photos}
        end
        expect(Bike.unscoped.where(serial_number: "69 photo-test").count).to eq 1
        bike = Bike.unscoped.where(serial_number: "69 photo-test").first
        expect(bike.example).to be_falsey
        expect(bike.public_images.count).to eq(1)
        expect(bike.current_ownership.origin).to eq "api_v1"
        expect(bike.current_ownership.creator).to eq bike.creator
        expect(bike.current_ownership.organization).to eq @organization
        expect(bike.rear_wheel_size.iso_bsd).to eq 559
      end

      include_context :geocoder_real
      it "creates a stolen record" do
        VCR.use_cassette("v1_bikes_create-stolen", match_requests_on: [:path]) do
          manufacturer = FactoryBot.create(:manufacturer)
          @organization.users.first.update_attribute :phone, "123-456-6969"
          FactoryBot.create(:state_illinois)
          bike_attrs = {
            serial_number: "69 stolen bike",
            manufacturer_id: manufacturer.id,
            rear_tire_narrow: "true",
            rear_wheel_size: 559,
            primary_frame_color_id: FactoryBot.create(:color).id,
            owner_email: "fun_times@examples.com",
            stolen: "true",
            phone: "9999999",
            cycle_type_slug: "bike"
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
            lock_defeat_description: "broken in some crazy way"
          }
          ActionMailer::Base.deliveries = []
          Sidekiq::Job.clear_all
          expect {
            post base_url, params: {bike: bike_attrs, stolen_record: stolen_record, organization_slug: @organization.slug, access_token: @organization.access_token}
          }.to change(Ownership, :count).by(1)
          expect(response.code).to eq("200")
          bike = Bike.unscoped.where(serial_number: "69 stolen bike").first
          expect(bike.example).to be_falsey
          expect(bike.current_ownership.origin).to eq "api_v1"
          expect(bike.current_ownership.creator).to eq bike.creator
          expect(bike.current_ownership.organization).to eq @organization
          expect(bike.rear_wheel_size.iso_bsd).to eq 559
          csr = bike.fetch_current_stolen_record
          expect(csr.address).to be_present
          expect(csr.phone).to eq("9999999")
          # No longer support this date format :/
          # expect(csr.date_stolen).to eq(DateTime.strptime("03-01-2013 06", "%m-%d-%Y %H"))
          expect(csr.locking_description).to eq("some locking description")
          expect(csr.lock_defeat_description).to eq("broken in some crazy way")
        end
      end

      it "creates an example bike if the bike is from example, and include all the options" do
        org = Organization.example
        user = FactoryBot.create(:user)
        FactoryBot.create(:organization_role_claimed, user: user, organization: org)
        manufacturer = FactoryBot.create(:manufacturer)
        org.save
        bike_attrs = {
          serial_number: "69 example bikez",
          cycle_type_slug: "unicycle",
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: "true",
          example: true,
          rear_wheel_size: 559,
          color: "grazeen",
          frame_material_slug: "Steel",
          handlebar_type_slug: "Other",
          description: "something else",
          owner_email: "fun_times@examples.com"
        }
        ActionMailer::Base.deliveries = []
        Sidekiq::Job.clear_all
        expect {
          post base_url, params: {bike: bike_attrs, organization_slug: org.slug, access_token: org.access_token}
        }.to change(Ownership, :count).by(1)
        Email::OwnershipInvitationJob.drain
        expect(ActionMailer::Base.deliveries.count).to eq 0
        expect(response.code).to eq("200")
        bike = Bike.unscoped.where(serial_number: "69 example bikez").first
        expect(bike.current_ownership.origin).to eq "api_v1"
        expect(bike.current_ownership.organization).to eq org
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

      it "creates a record even if the post is a string", :flaky do
        manufacturer = FactoryBot.create(:manufacturer)
        bike_attrs = {
          serial_number: "69 string",
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: "true",
          rear_wheel_bsd: "559",
          color: FactoryBot.create(:color).name,
          owner_email: "jsoned@examples.com",
          cycle_type: "tandem"
        }
        options = {bike: bike_attrs.to_json, organization_slug: @organization.slug, access_token: @organization.access_token}
        ActionMailer::Base.deliveries = []
        Sidekiq::Job.clear_all
        expect {
          post base_url, params: options
        }.to change(Ownership, :count).by(1)
        Email::OwnershipInvitationJob.drain
        expect(ActionMailer::Base.deliveries.count).to eq 1
        expect(response.code).to eq("200")
        bike = Bike.unscoped.where(serial_number: "69 string").first
        expect(bike.current_ownership.origin).to eq "api_v1"
        expect(bike.current_ownership.organization).to eq @organization
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
          cycle_type_name: " trailer "
        }
        options = {bike: bike.to_json, organization_slug: @organization.slug, access_token: @organization.access_token}
        ActionMailer::Base.deliveries = []
        Sidekiq::Job.clear_all
        expect {
          post base_url, params: options
        }.to change(Ownership, :count).by(1)
        Email::OwnershipInvitationJob.drain
        expect(ActionMailer::Base.deliveries.count).to eq(0)
        expect(response.code).to eq("200")
        bike = Bike.unscoped.where(serial_number: "69 string").first
        expect(bike.current_ownership.origin).to eq "api_v1"
        expect(bike.current_ownership.organization).to eq @organization
      end
    end
  end
end
