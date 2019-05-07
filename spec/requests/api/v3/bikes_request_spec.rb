require "spec_helper"

describe "Bikes API V3" do
  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let(:color) { FactoryBot.create(:color) }
  include_context :existing_doorkeeper_app

  describe "find by id" do
    it "returns one with from an id" do
      bike = FactoryBot.create(:bike)
      get "/api/v3/bikes/#{bike.id}", format: :json
      expect(response.code).to eq("200")
      expect(json_result["bike"]["id"]).to eq(bike.id)
      expect(response.headers["Content-Type"].match("json")).to be_present
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(response.headers["Access-Control-Request-Method"]).to eq("*")
    end

    it "responds with missing" do
      get "/api/v3/bikes/10", format: :json
      expect(response.code).to eq("404")
      expect(json_result["error"].present?).to be_truthy
      expect(response.headers["Content-Type"].match("json")).to be_present
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(response.headers["Access-Control-Request-Method"]).to eq("*")
    end
  end

  describe "create" do
    let(:bike_attrs) do
      {
        serial: "69 non-example",
        manufacturer: manufacturer.name,
        rear_tire_narrow: "true",
        rear_wheel_bsd: "559",
        color: color.name,
        year: "1969",
        owner_email: "fun_times@examples.com",
        frame_material: "steel",
      }
    end
    let!(:token) { create_doorkeeper_token(scopes: "read_bikes write_bikes") }
    before :each do
      FactoryBot.create(:wheel_size, iso_bsd: 559)
    end
    include_context :geocoder_default_location

    context "no token" do
      let(:token) { nil }
      it "responds with 401" do
        post "/api/v3/bikes", bike_attrs.to_json
        expect(response.code).to eq("401")
      end
    end

    context "without write_bikes scope" do
      let!(:token) { create_doorkeeper_token(scopes: "read_bikes") }
      it "fails" do
        post "/api/v3/bikes?access_token=#{token.token}", bike_attrs.to_json, json_headers
        expect(response.code).to eq("403")
      end
    end

    context "unconfirmed user" do
      let(:user) { FactoryBot.create(:user) }
      let!(:token) { create_doorkeeper_token(scopes: "read_bikes write_bikes unconfirmed") }
      it "fails" do
        expect(user.unconfirmed?).to be_truthy
        expect(token.resource_owner_id).to eq user.id
        post "/api/v3/bikes?access_token=#{token.token}", bike_attrs.to_json, json_headers
        expect(response.code).to eq("403")
      end
    end

    context "given a matching pre-existing bike record" do
      context "if the POSTer is authorized to update" do
        it "does not create a new record" do
          post "/api/v3/bikes?access_token=#{token.token}",
               bike_attrs.to_json,
               json_headers

          expect(response.status).to eq(201)
          expect(response.status_message).to eq("Created")
          bike1 = json_result["bike"]

          post "/api/v3/bikes?access_token=#{token.token}",
               bike_attrs.to_json,
               json_headers

          bike2 = json_result["bike"]
          expect(response.status).to eq(302)
          expect(response.status_message).to eq("Found")
          expect(bike1["id"]).to eq(bike2["id"])
        end

        it "updates the pre-existing record" do
          old_color = FactoryBot.create(:color, name: "old_color")
          new_color = FactoryBot.create(:color, name: "new_color")
          old_manufacturer = FactoryBot.create(:manufacturer, name: "old_manufacturer")
          new_manufacturer = FactoryBot.create(:manufacturer, name: "new_manufacturer")
          old_wheel_size = FactoryBot.create(:wheel_size, name: "old_wheel_size", iso_bsd: 10)
          new_rear_wheel_size = FactoryBot.create(:wheel_size, name: "new_rear_wheel_size", iso_bsd: 11)
          new_front_wheel_size = FactoryBot.create(:wheel_size, name: "new_front_wheel_size", iso_bsd: 12)
          old_cycle_type = CycleType.new("unicycle")
          new_cycle_type = CycleType.new("tricycle")
          old_year = 1969
          new_year = 2001
          bike1 = FactoryBot.create(
            :bike,
            creator: user,
            owner_email: user.email,
            year: old_year,
            manufacturer: old_manufacturer,
            primary_frame_color: old_color,
            cycle_type: old_cycle_type.id,
            rear_wheel_size: old_wheel_size,
            front_wheel_size: old_wheel_size,
            rear_tire_narrow: false,
            frame_material: "aluminum",
          )
          FactoryBot.create(:ownership, bike: bike1, creator: user, owner_email: user.email)

          bike_attrs = {
            serial: bike1.serial_number,
            manufacturer: new_manufacturer.name,
            rear_tire_narrow: true,
            front_wheel_bsd: new_front_wheel_size.iso_bsd,
            rear_wheel_bsd: new_rear_wheel_size.iso_bsd,
            color: new_color.name,
            year: new_year,
            owner_email: user.email,
            frame_material: "steel",
            cycle_type_name: new_cycle_type.slug.to_s,
          }
          post "/api/v3/bikes?access_token=#{token.token}",
               bike_attrs.to_json,
               json_headers

          bike2 = json_result["bike"]
          expect(bike2["id"]).to eq(bike1.id)
          expect(bike2["serial"]).to eq(bike1.serial)
          expect(bike2["year"]).to eq(new_year)
          expect(bike2["frame_colors"].first).to eq(new_color.name)
          expect(bike2["type_of_cycle"]).to eq(new_cycle_type.name)
          expect(bike2["manufacturer_id"]).to eq(old_manufacturer.id)
          expect(bike2["front_wheel_size_iso_bsd"]).to eq(new_front_wheel_size.iso_bsd)
          expect(bike2["rear_wheel_size_iso_bsd"]).to eq(new_rear_wheel_size.iso_bsd)
          expect(bike2["rear_tire_narrow"]).to eq(true)
          expect(bike2["frame_material"]).to eq("Steel")
        end
      end

      context "if the matching bike is unclaimed" do
        it "updates if the submitting org is the creation org" do
          bike = FactoryBot.create(:creation_organization_bike)
          FactoryBot.create(:ownership, creator: bike.creator, bike: bike)
          FactoryBot.create(:existing_membership, user: user, organization: bike.creation_organization)

          bike_attrs = {
            serial: bike.serial,
            manufacturer: bike.manufacturer.name,
            color: color.name,
            year: bike.year,
            owner_email: bike.owner_email,
          }
          post "/api/v3/bikes?access_token=#{token.token}",
               bike_attrs.to_json,
               json_headers

          returned_bike = json_result["bike"]
          expect(response.status).to eq(302)
          expect(response.status_message).to eq("Found")
          expect(returned_bike["id"]).to eq(bike.id)
        end

        it "creates a new record if the submitting org isn't the creation org" do
          bike = FactoryBot.create(:creation_organization_bike)
          FactoryBot.create(:ownership, creator: bike.creator, bike: bike)
          FactoryBot.create(:existing_membership, user: user)

          bike_attrs = {
            serial: bike.serial,
            manufacturer: bike.manufacturer.name,
            color: color.name,
            year: bike.year,
            owner_email: bike.owner_email,
          }
          post "/api/v3/bikes?access_token=#{token.token}",
               bike_attrs.to_json,
               json_headers

          returned_bike = json_result["bike"]
          expect(response.status).to eq(201)
          expect(response.status_message).to eq("Created")
          expect(returned_bike["id"]).to_not eq(bike.id)
        end
      end

      context "if the matching bike is claimed" do
        it "creates a new bike" do
          bike = FactoryBot.create(:creation_organization_bike)
          FactoryBot.create(:ownership_claimed, creator: bike.creator, bike: bike)
          FactoryBot.create(:existing_membership, user: user, organization: bike.creation_organization)

          bike_attrs = {
            serial: bike.serial,
            manufacturer: bike.manufacturer.name,
            color: color.name,
            year: bike.year,
            owner_email: bike.owner_email,
          }
          post "/api/v3/bikes?access_token=#{token.token}",
               bike_attrs.to_json,
               json_headers

          returned_bike = json_result["bike"]
          expect(response.status).to eq(201)
          expect(response.status_message).to eq("Created")
          expect(returned_bike["id"]).to_not eq(bike.id)
        end
      end
    end

    context "given a bike with a pre-existing match by a normalized serial number" do
      it "responds with the match instead of creating a duplicate" do
        bike_attrs = {
          serial: "serial-Ol",
          manufacturer: manufacturer.name,
          color: color.name,
          year: "1969",
          owner_email: "bike-serial-01@examples.com",
        }
        post "/api/v3/bikes?access_token=#{token.token}",
             bike_attrs.to_json,
             json_headers

        expect(response.status).to eq(201)
        expect(response.status_message).to eq("Created")
        bike1 = json_result["bike"]

        bike_attrs = bike_attrs.merge(serial: "serial-01")
        post "/api/v3/bikes?access_token=#{token.token}",
             bike_attrs.to_json,
             json_headers

        bike2 = json_result["bike"]
        expect(response.status).to eq(302)
        expect(response.status_message).to eq("Found")
        expect(bike1["id"]).to eq(bike2["id"])
      end
    end

    context "given a bike with a pre-existing match by a normalized email" do
      it "responds with the match instead of creating a duplicate" do
        bike_attrs = {
          serial: "serial-01",
          manufacturer: manufacturer.name,
          color: color.name,
          year: "1969",
          owner_email: "bike-serial-01@example.com",
        }
        post "/api/v3/bikes?access_token=#{token.token}",
             bike_attrs.to_json,
             json_headers

        expect(response.status).to eq(201)
        expect(response.status_message).to eq("Created")
        bike1 = json_result["bike"]

        bike_attrs = bike_attrs.merge(owner_email: "  bike-serial-01@example.com  ")
        post "/api/v3/bikes?access_token=#{token.token}",
             bike_attrs.to_json,
             json_headers

        bike2 = json_result["bike"]
        expect(response.status).to eq(302)
        expect(response.status_message).to eq("Found")
        expect(bike1["id"]).to eq(bike2["id"])
      end
    end

    context "given a bike with a pre-existing match by an owning user's secondary email" do
      it "responds with the match instead of creating a duplicate" do
        user.user_emails.create(email: "secondary-email@example.com")
        bike = FactoryBot.create(:ownership, creator: user).bike

        bike_attrs = {
          serial: bike.serial,
          manufacturer: bike.manufacturer.name,
          color: color.name,
          year: bike.year,
          owner_email: user.secondary_emails.first,
        }
        post "/api/v3/bikes?access_token=#{token.token}",
             bike_attrs.to_json,
             json_headers

        returned_bike = json_result["bike"]
        expect(response.status).to eq(302)
        expect(response.status_message).to eq("Found")
        expect(returned_bike["id"]).to eq(bike.id)
      end
    end

    context "given a bike with a pre-existing match by serial" do
      it "creates a new bike if the match has a different owner" do
        bike = FactoryBot.create(:ownership, creator: user).bike

        bike_attrs = {
          serial: bike.serial,
          manufacturer: bike.manufacturer.name,
          color: color.name,
          year: bike.year,
          owner_email: "some-other-owner@example.com",
        }
        post "/api/v3/bikes?access_token=#{token.token}",
             bike_attrs.to_json,
             json_headers

        returned_bike = json_result["bike"]
        expect(response.status).to eq(201)
        expect(response.status_message).to eq("Created")
        expect(returned_bike["id"]).to_not eq(bike.id)
      end
    end

    it "creates a non example bike, with components" do
      manufacturer = FactoryBot.create(:manufacturer)
      FactoryBot.create(:ctype, name: "wheel")
      FactoryBot.create(:ctype, name: "Headset")
      front_gear_type = FactoryBot.create(:front_gear_type)
      handlebar_type_slug = "bmx"
      components = [
        {
          manufacturer: manufacturer.name,
          year: "1999",
          component_type: "headset",
          description: "yeah yay!",
          serial_number: "69",
          model: "Richie rich",
        },
        {
          manufacturer: "BLUE TEETH",
          front_or_rear: "Both",
          component_type: "wheel",
        },
      ]
      bike_attrs.merge!(components: components,
                        front_gear_type_slug: front_gear_type.slug,
                        handlebar_type_slug: handlebar_type_slug,
                        is_for_sale: true,
                        is_bulk: true,
                        is_new: true,
                        is_pos: true,
                        external_image_urls: ["https://files.bikeindex.org/email_assets/bike_photo_placeholder.png"],
                        description: "<svg/onload=alert(document.cookie)>")
      expect do
        post "/api/v3/bikes?access_token=#{token.token}",
             bike_attrs.to_json,
             json_headers
      end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(1)
      expect(response.code).to eq("201")
      result = json_result["bike"]
      expect(result["serial"]).to eq(bike_attrs[:serial])
      expect(result["manufacturer_name"]).to eq(bike_attrs[:manufacturer])
      bike = Bike.find(result["id"])
      expect(bike.example).to be_falsey
      expect(bike.is_for_sale).to be_truthy
      expect(bike.frame_material).to eq(bike_attrs[:frame_material])
      expect(bike.components.count).to eq(3)
      expect(bike.components.pluck(:manufacturer_id).include?(manufacturer.id)).to be_truthy
      expect(bike.components.pluck(:ctype_id).uniq.count).to eq(2)
      expect(bike.front_gear_type).to eq(front_gear_type)
      expect(bike.handlebar_type).to eq(handlebar_type_slug)
      expect(bike.external_image_urls).to eq(["https://files.bikeindex.org/email_assets/bike_photo_placeholder.png"])
      creation_state = bike.creation_state
      expect([creation_state.is_pos, creation_state.is_new, creation_state.is_bulk]).to eq([true, true, true])
      # expect(creation_state.origin).to eq 'api_v3'

      # We return things will alert if they're written directly to the dom - worth noting, since it might be a problem
      expect(result["description"]).to eq "<svg/onload=alert(document.cookie)>"
      expect(bike.description).to eq "<svg/onload=alert(document.cookie)>"
    end

    it "doesn't send an email" do
      expect do
        post "/api/v3/bikes?access_token=#{token.token}",
             bike_attrs.merge(no_notify: true).to_json,
             json_headers
      end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(0)
      expect(response.code).to eq("201")
    end

    it "creates an example bike" do
      FactoryBot.create(:organization, name: "Example organization")
      expect do
        post "/api/v3/bikes?access_token=#{token.token}",
             bike_attrs.merge(test: true).to_json,
             json_headers
      end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(0)
      expect(response.code).to eq("201")
      result = json_result["bike"]
      expect(result["serial"]).to eq(bike_attrs[:serial])
      expect(result["manufacturer_name"]).to eq(bike_attrs[:manufacturer])
      bike = Bike.unscoped.find(result["id"])
      # expect(bike.creation_state.origin).to eq 'api_v3'
      expect(bike.example).to be_truthy
      expect(bike.is_for_sale).to be_falsey
    end

    it "creates a stolen bike through an organization and uses the passed phone" do
      organization = FactoryBot.create(:organization)
      user.update_attribute :phone, "0987654321"
      FactoryBot.create(:membership, user: user, organization: organization)
      FactoryBot.create(:country, iso: "US")
      FactoryBot.create(:state, abbreviation: "NY")
      organization.save
      bike_attrs[:organization_slug] = organization.slug
      date_stolen = 1357192800
      bike_attrs[:stolen_record] = {
        phone: "1234567890",
        date_stolen: date_stolen,
        theft_description: "This bike was stolen and that's no fair.",
        country: "US",
        city: "New York",
        street: "278 Broadway",
        zipcode: "10007",
        show_address: true,
        state: "NY",
        police_report_number: "99999999",
        police_report_department: "New York",
      # locking_description: "some locking description",
      # lock_defeat_description: "broken in some crazy way"
      }
      expect do
        post "/api/v3/bikes?access_token=#{token.token}",
             bike_attrs.to_json,
             json_headers
      end.to change(EmailOwnershipInvitationWorker.jobs, :size).by(1)
      expect(json_result).to include("bike")
      expect(json_result["bike"]["serial"]).to eq(bike_attrs[:serial])
      expect(json_result["bike"]["manufacturer_name"]).to eq(bike_attrs[:manufacturer])
      expect(json_result["bike"]["stolen_record"]["date_stolen"]).to eq(date_stolen)
      bike = Bike.find(json_result["bike"]["id"])
      expect(bike.creation_organization).to eq(organization)
      expect(bike.creation_state.origin).to eq "api_v2" # Because it just inherits v2 :/
      expect(bike.creation_state.organization).to eq organization
      expect(bike.stolen).to be_truthy
      expect(bike.current_stolen_record_id).to be_present
      expect(bike.current_stolen_record.police_report_number).to eq(bike_attrs[:stolen_record][:police_report_number])
      expect(bike.current_stolen_record.phone).to eq("1234567890")
      expect(bike.current_stolen_record.show_address).to be_truthy
    end

    it "does not register a stolen bike unless attrs are present" do
      bike_attrs[:stolen_record] = {
        phone: "",
        theft_description: "This bike was stolen and that's no fair.",
        city: "Chicago",
      }
      expect do
        post "/api/v3/bikes?access_token=#{token.token}",
             bike_attrs.to_json,
             json_headers
      end.to change(Ownership, :count).by 0
      expect(json_result["error"]).to be_present
    end
  end

  describe "create v3_accessor" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:bike_attrs) do
      {
        serial: "69 non-example",
        manufacturer: manufacturer.name,
        rear_tire_narrow: "true",
        rear_wheel_bsd: "559",
        color: color.name,
        year: "1969",
        owner_email: "fun_times@examples.com",
        organization_slug: organization.slug,
        cycle_type: "bike",
      }
    end
    let!(:tokenized_url) { "/api/v2/bikes?access_token=#{v2_access_token.token}" }
    before :each do
      FactoryBot.create(:wheel_size, iso_bsd: 559)
    end

    context "with membership" do
      before do
        FactoryBot.create(:membership, user: user, organization: organization, role: "admin")
        organization.save
        ActionMailer::Base.deliveries = []
      end

      context "duplicated serial" do
        context "matching email" do
          it "returns existing bike if authorized by organization" do
            email = bike_attrs[:owner_email]
            bike = FactoryBot.create(:bike, serial_number: bike_attrs[:serial], owner_email: email)
            bike.organizations << organization
            bike.save
            ownership = FactoryBot.create(:ownership, bike: bike, owner_email: email)

            expect(ownership.claimed).to be_falsey

            expect {
              post tokenized_url,
                   bike_attrs.merge(no_duplicate: true).to_json,
                   json_headers
            }.to change(Bike, :count).by 0

            result = json_result["bike"]
            expect(response.status).to eq(302)
            expect(response.status_message).to eq("Found")
            expect(result["id"]).to eq bike.id

            EmailOwnershipInvitationWorker.drain
            expect(ActionMailer::Base.deliveries).to be_empty
          end
        end

        context "non-matching email" do
          let(:email) { "another_email@example.com" }
          it "creates a bike for organization with v3_accessor" do
            bike = FactoryBot.create(:bike, serial_number: bike_attrs[:serial], owner_email: email)
            ownership = FactoryBot.create(:ownership, bike: bike, owner_email: email)
            expect(ownership.claimed).to be_falsey
            expect do
              post tokenized_url, bike_attrs.to_json, json_headers
            end.to change(Bike, :count).by 1
            result = json_result["bike"]

            expect(response.code).to eq("201")
            bike = Bike.find(result["id"])
            expect(bike.creation_organization).to eq(organization)
            expect(bike.creator).to eq(user)
            expect(bike.secondary_frame_color).to be_nil
            expect(bike.rear_wheel_size.iso_bsd).to eq 559
            expect(bike.front_wheel_size.iso_bsd).to eq 559
            expect(bike.rear_tire_narrow).to be_truthy
            expect(bike.front_tire_narrow).to be_truthy
            # expect(bike.creation_state.origin).to eq 'api_v3'
            expect(bike.creation_state.organization).to eq organization
            EmailOwnershipInvitationWorker.drain
            expect(ActionMailer::Base.deliveries).to_not be_empty
          end
        end
      end

      it "doesn't create a bike without an organization with v3_accessor" do
        post tokenized_url, bike_attrs.except(:organization_slug).to_json, json_headers
        expect(response.code).to eq("403")
        expect(json_result["error"].is_a?(String)).to be_truthy
        EmailOwnershipInvitationWorker.drain
        expect(ActionMailer::Base.deliveries).to be_empty
      end
    end

    it "fails to create a bike if the app owner isn't a member of the organization" do
      expect(user.has_membership?).to be_falsey
      post tokenized_url, bike_attrs.to_json, json_headers
      expect(response.code).to eq("403")
      expect(json_result["error"].is_a?(String)).to be_truthy
    end
  end

  describe "update" do
    let(:params) { { year: 1999, serial_number: "XXX69XXX" } }
    let(:url) { "/api/v3/bikes/#{bike.id}?access_token=#{token.token}" }
    let(:bike) { FactoryBot.create(:ownership, creator_id: user.id).bike }
    let!(:token) { create_doorkeeper_token(scopes: "read_user read_bikes write_bikes") }

    it "doesn't update if user doesn't own the bike" do
      bike.current_ownership.update_attributes(user_id: FactoryBot.create(:user).id, claimed: true)
      allow_any_instance_of(Bike).to receive(:type).and_return("unicorn")
      put url, params.to_json, json_headers
      expect(response.body.match("do not own that unicorn")).to be_present
      expect(response.code).to eq("403")
    end

    it "doesn't update if not in scope" do
      token.update_attribute :scopes, "public"
      put url, params.to_json, json_headers
      expect(response.code).to eq("403")
      expect(response.body).to match(/oauth/i)
      expect(response.body).to match(/permission/i)
    end

    it "fails to update bike if required stolen attrs aren't present" do
      FactoryBot.create(:country, iso: "US")
      expect(bike.year).to be_nil
      params[:stolen_record] = {
        phone: "",
        city: "Chicago",
      }
      put url, params.to_json, json_headers
      expect(response.code).to eq("401")
      expect(response.body.match("missing phone")).to be_present
    end

    it "updates a bike, adds a stolen record, doesn't update locked attrs" do
      FactoryBot.create(:country, iso: "US")
      expect(bike.year).to be_nil
      serial = bike.serial_number
      params[:stolen_record] = {
        city: "Chicago",
        phone: "1234567890",
        show_address: true,
        police_report_number: "999999",
      }
      params[:owner_email] = "foo@new_owner.com"
      expect do
        put url, params.to_json, json_headers
      end.to change(Ownership, :count).by(1)
      expect(response.code).to eq("200")
      expect(bike.reload.year).to eq(params[:year])
      expect(bike.serial_number).to eq(serial)
      expect(bike.stolen).to be_truthy
      expect(bike.current_stolen_record.date_stolen.to_i).to be > Time.now.to_i - 10
      expect(bike.current_stolen_record.police_report_number).to eq("999999")
      expect(bike.current_stolen_record.show_address).to be_truthy
    end

    it "updates a bike, adds and removes components" do
      # FactoryBot.create(:manufacturer, name: 'Other')
      wheels = FactoryBot.create(:ctype, name: "wheel")
      headsets = FactoryBot.create(:ctype, name: "Headset")
      comp = FactoryBot.create(:component, bike: bike, ctype: headsets)
      comp2 = FactoryBot.create(:component, bike: bike, ctype: wheels)
      not_urs = FactoryBot.create(:component)
      bike.reload
      expect(bike.components.count).to eq(2)
      components = [
        {
          manufacturer: manufacturer.name,
          year: "1999",
          component_type: "headset",
          description: "Second component",
          serial_number: "69",
          model: "Sram GXP Eagle",
        }, {
          manufacturer: "BLUE TEETH",
          front_or_rear: "Rear",
          description: "third component",
        }, {
          id: comp.id,
          destroy: true,
        }, {
          id: comp2.id,
          year: "1999",
          description: "First component",
        },
      ]
      params[:is_for_sale] = true
      params[:components] = components
      expect do
        put url, params.to_json, json_headers
      end.to change(Ownership, :count).by(0)
      expect(response.code).to eq("200")
      bike.reload
      bike.components.reload
      expect(bike.is_for_sale).to be_truthy
      expect(bike.year).to eq(params[:year])
      expect(comp2.reload.year).to eq(1999)
      expect(bike.components.pluck(:manufacturer_id).include?(manufacturer.id)).to be_truthy
      expect(bike.components.map(&:cmodel_name).compact).to eq(["Sram GXP Eagle"])
      expect(bike.components.count).to eq(3)
    end

    it "doesn't remove components that aren't the bikes" do
      manufacturer = FactoryBot.create(:manufacturer)
      comp = FactoryBot.create(:component, bike: bike)
      not_urs = FactoryBot.create(:component)
      components = [
        {
          id: comp.id,
          year: 1999,
        }, {
          id: not_urs.id,
          destroy: true,
        },
      ]
      params[:components] = components
      put url, params.to_json, json_headers
      expect(response.code).to eq("401")
      expect(response.headers["Content-Type"].match("json")).to be_present
      # response.headers['Access-Control-Allow-Origin'].should eq('*')
      # response.headers['Access-Control-Request-Method'].should eq('*')
      expect(bike.reload.components.reload.count).to eq(1)
      expect(bike.components.pluck(:year).first).to eq(1999) # Feature, not a bug?
      expect(not_urs.reload.id).to be_present
    end

    it "claims a bike and updates if it should" do
      expect(bike.year).to be_nil
      bike.current_ownership.update_attributes(owner_email: user.email, creator_id: FactoryBot.create(:user).id, claimed: false)
      expect(bike.reload.owner).not_to eq(user)
      put url, params.to_json, json_headers
      expect(response.code).to eq("200")
      expect(response.headers["Content-Type"].match("json")).to be_present
      expect(bike.reload.current_ownership.claimed).to be_truthy
      expect(bike.owner).to eq(user)
      expect(bike.year).to eq(params[:year])
    end

    context "organization bike" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:ownership) { FactoryBot.create(:ownership_organization_bike, organization: organization) }
      let(:user) { FactoryBot.create(:organization_member, organization: organization) }
      let(:params) { { year: 1999, external_image_urls: ["https://files.bikeindex.org/email_assets/logo.png"] } }
      let(:bike) { ownership.bike }
      let!(:token) { create_doorkeeper_token(scopes: "read_user read_bikes write_bikes") }
      it "permits updating" do
        bike.reload
        expect(bike.public_images.count).to eq 0
        expect(bike.owner).to_not eq(user)
        expect(bike.authorized_by_organization?(u: user)).to be_truthy
        expect(bike.authorize_for_user(user)).to be_truthy
        expect(bike.claimed?).to be_falsey
        expect(bike.current_ownership.claimed?).to be_falsey
        put url, params.to_json, json_headers
        expect(response.code).to eq("200")
        expect(response.headers["Content-Type"].match("json")).to be_present
        bike.reload
        expect(bike.claimed?).to be_falsey
        expect(bike.authorized_by_organization?(u: user)).to be_truthy
        expect(bike.reload.owner).to_not eq user
        expect(bike.year).to eq params[:year]
        expect(bike.external_image_urls).to eq([]) # Because we haven't created another bparam - this could change though
        expect(bike.public_images.count).to eq 1
      end
    end
  end

  describe "image" do
    let!(:token) { create_doorkeeper_token(scopes: "read_user write_bikes") }
    it "doesn't post an image to a bike if the bike isn't owned by the user" do
      bike = FactoryBot.create(:ownership).bike
      file = File.open(File.join(Rails.root, "spec", "fixtures", "bike.jpg"))
      url = "/api/v3/bikes/#{bike.id}/image?access_token=#{token.token}"
      expect(bike.public_images.count).to eq(0)
      post url, file: Rack::Test::UploadedFile.new(file)
      expect(response.code).to eq("403")
      expect(response.headers["Content-Type"].match("json")).to be_present
      expect(bike.reload.public_images.count).to eq(0)
    end

    it "errors on non whitelisted extensions" do
      bike = FactoryBot.create(:ownership, creator_id: user.id).bike
      file = File.open(File.join(Rails.root, "spec", "spec_helper.rb"))
      url = "/api/v3/bikes/#{bike.id}/image?access_token=#{token.token}"
      expect(bike.public_images.count).to eq(0)
      post url, file: Rack::Test::UploadedFile.new(file)
      expect(response.body.match(/not allowed to upload .?.rb/i)).to be_present
      expect(response.code).to eq("401")
      expect(bike.reload.public_images.count).to eq(0)
    end

    it "posts an image" do
      bike = FactoryBot.create(:ownership, creator_id: user.id).bike
      file = File.open(File.join(Rails.root, "spec", "fixtures", "bike.jpg"))
      url = "/api/v3/bikes/#{bike.id}/image?access_token=#{token.token}"
      expect(bike.public_images.count).to eq(0)
      post url, file: Rack::Test::UploadedFile.new(file)
      expect(response.code).to eq("201")
      expect(response.headers["Content-Type"].match("json")).to be_present
      expect(bike.reload.public_images.count).to eq(1)
    end
  end

  describe "send_stolen_notification" do
    let(:bike) { FactoryBot.create(:ownership, creator_id: user.id).bike }
    let(:params) { { message: "Something I'm sending you" } }
    let(:url) { "/api/v3/bikes/#{bike.id}/send_stolen_notification?access_token=#{token.token}" }
    let!(:token) { create_doorkeeper_token(scopes: "read_user") }
    before { bike.update_attribute :stolen, true }

    it "fails to send a stolen notification without read_user" do
      token.update_attribute :scopes, "public"
      post url, params.to_json, json_headers
      expect(response.code).to eq("403")
      expect(response.body).to match("OAuth")
      expect(response.body).to match(/permission/i)
      expect(response.body).to_not match("is not stolen")
    end

    it "fails if the bike isn't stolen" do
      bike.update_attribute :stolen, false
      post url, params.to_json, json_headers
      expect(response.code).to eq("400")
      expect(response.body.match("is not stolen")).to be_present
    end

    it "fails if the bike isn't owned by the access token user" do
      bike.current_ownership.update_attributes(user_id: FactoryBot.create(:user).id, claimed: true)
      post url, params.to_json, json_headers
      expect(response.code).to eq("403")
      expect(response.body.match("application is not approved")).to be_present
    end

    it "sends a notification" do
      expect do
        post url, params.to_json, json_headers
      end.to change(EmailStolenNotificationWorker.jobs, :size).by(1)
      expect(response.code).to eq("201")
    end
  end
end
