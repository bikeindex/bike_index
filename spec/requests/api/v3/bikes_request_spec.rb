require "rails_helper"

RSpec.describe "Bikes API V3", type: :request do
  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let(:color) { FactoryBot.create(:color) }
  let(:organization) { nil }
  let(:auto_user) { organization&.reload&.auto_user }
  let(:email) { "fun_times@examples.com" }
  let(:bike_attrs) do
    {
      serial: "69 NON-EXAMPLE",
      manufacturer: manufacturer.name,
      rear_tire_narrow: "true",
      rear_wheel_bsd: "559",
      color: color.name,
      year: "1969",
      owner_email: email,
      frame_material: "steel",
      organization_slug: organization&.slug,
      cycle_type: "bike"
    }
  end
  include_context :existing_doorkeeper_app

  describe "find by id" do
    it "returns one with from an id" do
      bike = FactoryBot.create(:bike)
      get "/api/v3/bikes/#{bike.id}", params: {format: :json}
      expect(response.code).to eq("200")
      expect(json_result["bike"]["id"]).to eq(bike.id)
      expect(response.headers["Content-Type"].match("json")).to be_present
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(response.headers["Access-Control-Request-Method"]).to eq("*")
    end

    it "responds with missing" do
      get "/api/v3/bikes/10", params: {format: :json}
      expect(response.code).to eq("404")
      expect(json_result["error"].present?).to be_truthy
      expect(response.headers["Content-Type"].match("json")).to be_present
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(response.headers["Access-Control-Request-Method"]).to eq("*")
    end
  end

  describe "check_if_registered" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:search_params) do
      {
        serial: "SNFBT22609255533",
        organization_slug: organization&.slug,
        owner_email: email,
        manufacturer: manufacturer.name,
        cycle_type_name: "bike", # Ignored
        color: color.name # Ignored
      }
    end
    def create_attrs(search_hash)
      search_hash.except(:serial, :manufacturer, :color, :organization_slug, :match_all_parameters, :cycle_type_name)
        .merge(serial_number: search_hash[:serial], manufacturer: manufacturer, primary_frame_color: color, cycle_type: search_hash[:cycle_type_name])
    end
    let!(:bike) { FactoryBot.create(:bike, :with_ownership, create_attrs(search_params)) }
    let!(:token) { create_doorkeeper_token(scopes: "read_bikes write_bikes") }
    let(:check_if_registered_url) { "/api/v3/bikes/check_if_registered?access_token=#{token.token}" }
    it "returns 401" do
      expect(bike.reload.claimed?).to be_falsey
      expect(bike.authorized?(user)).to be_falsey
      post check_if_registered_url, params: search_params.to_json, headers: json_headers
      expect(response.code).to eq("401")
      expect(json_result["error"]).to match(/authorized.*organization/i)
      # Without org slug
      post check_if_registered_url, params: search_params.except(:organization_slug).to_json, headers: json_headers
      expect(response.code).to match(/40\d/)
      expect(json_result["error"]).to match(/organization.*missing/i)
      # With unknown org slug
      post check_if_registered_url, params: search_params.merge(organization_slug: "bbbb").to_json, headers: json_headers
      expect(response.code).to match(/40\d/)
      expect(json_result["error"]).to match(/organization/i)
    end
    context "user is organization member" do
      let(:user) { FactoryBot.create(:organization_user) }
      let!(:organization) { user.organizations.first }
      let(:target_result) { {registered: true, claimed: false, can_edit: false, state: "with_user", authorized_bike_id: nil} }
      let(:unmatched_result) { {registered: false, claimed: false, can_edit: false, state: "no_matching_bike", authorized_bike_id: nil} }
      let(:organized_bike) { {} }
      let(:required_params) { search_params.slice(:serial, :owner_email, :organization_slug) }
      it "returns target" do
        expect(bike.reload.claimed?).to be_falsey
        expect(bike.authorized?(user)).to be_falsey
        post check_if_registered_url, params: search_params.to_json, headers: json_headers
        expect(response.code).to eq("201")
        expect(json_result).to match_hash_indifferently target_result

        post check_if_registered_url, params: required_params.to_json, headers: json_headers
        expect(response.code).to eq("201")
        expect(json_result).to match_hash_indifferently target_result
        # normalized serial match
        post check_if_registered_url, params: required_params.merge(serial: "SNFBT226092sss33").to_json, headers: json_headers
        expect(response.code).to eq("201")
        expect(json_result).to match_hash_indifferently target_result
        # It doesn't match if a different manufacturer
        manufacturer2 = FactoryBot.create(:manufacturer)
        post check_if_registered_url, params: required_params.merge(manufacturer: manufacturer2.name).to_json, headers: json_headers
        expect(response.code).to eq("201")
        expect(json_result).to match_hash_indifferently unmatched_result
        # It matches if passed an unknown manufacturer
        post check_if_registered_url, params: required_params.merge(manufacturer: "some other Manufacturer").to_json, headers: json_headers
        expect(response.code).to eq("201")
        expect(json_result).to match_hash_indifferently target_result

        # It matches via user secondary email address
        owner = FactoryBot.create(:user, :confirmed, email: "2@dddd.com")
        FactoryBot.create(:user_email, user: owner, email: bike.owner_email)
        expect(owner.reload.confirmed_emails).to match_array(["2@dddd.com", bike.owner_email])
        post check_if_registered_url, params: required_params.merge(email: "2@DDDD.com").to_json, headers: json_headers
        expect(response.code).to eq("201")
        expect(json_result).to match_hash_indifferently target_result
      end
      context "bike is authorized" do
        let(:target_result) do
          {
            authorized_bike_id: bike.id,
            can_edit: true,
            claimed: false,
            registered: true,
            state: "with_user"
          }
        end
        it "returns target" do
          # If the user is authorized via a secondary email
          user_email = FactoryBot.create(:user_email, user: user, email: bike.owner_email)
          expect(bike.reload.claimed?).to be_falsey
          expect(bike.authorized?(user)).to be_truthy
          post check_if_registered_url, params: search_params.to_json, headers: json_headers
          expect(response.code).to eq("201")
          expect(json_result).to match_hash_indifferently target_result
          # Sanity check
          user_email.destroy
          post check_if_registered_url, params: search_params.to_json, headers: json_headers
          expect(response.code).to eq("201")
          expect(json_result).to match_hash_indifferently target_result.merge(can_edit: false, authorized_bike_id: nil)
          # Test via bike organization
          bike_organization = BikeOrganization.create(bike: bike, organization: organization)
          expect(bike_organization).to be_valid
          expect(bike.reload.authorized?(user)).to be_truthy
          post check_if_registered_url, params: required_params.to_json, headers: json_headers
          expect(response.code).to eq("201")
          expect(json_result).to match_hash_indifferently target_result
        end
      end
      context "v2_accessor" do
        let(:check_if_registered_url) { "/api/v3/bikes/check_if_registered?access_token=#{v2_access_token.token}" }
        it "returns unauthorized" do
          expect(bike.reload.claimed?).to be_falsey
          expect(bike.authorized?(user)).to be_falsey
          post check_if_registered_url, params: search_params.to_json, headers: json_headers
          expect(response.code).to eq("403")
          expect(json_result["error"].is_a?(String)).to be_truthy
          expect(json_result["error"]).to match(/permanent token/i)
        end
      end
      context "state: stolen" do
        let(:target_result) do
          {
            authorized_bike_id: nil,
            can_edit: false,
            claimed: false,
            registered: true,
            state: "stolen"
          }
        end
        let!(:stolen_record) { FactoryBot.create(:stolen_record, bike: bike, date_stolen: Time.current - 1.year) }
        before { bike.update(updated_at: Time.current) }
        it "returns target" do
          expect(bike.reload.status).to eq "status_stolen"
          post check_if_registered_url, params: search_params.to_json, headers: json_headers
          expect(response.code).to eq("201")
          expect(json_result).to match_hash_indifferently target_result
        end
        context "recovered" do
          let(:target_result) { {registered: true, claimed: false, can_edit: false, state: "recovered", authorized_bike_id: nil} }
          it "returns target" do
            stolen_record.add_recovery_information(recovered_at: Time.current - 1.week)
            post check_if_registered_url, params: search_params.to_json, headers: json_headers
            expect(response.code).to eq("201")
            expect(json_result).to match_hash_indifferently target_result
            # if recovery is more than a year ago, it goes back to being `with_user`
            stolen_record.update(recovered_at: Time.current - 2.years)
            post check_if_registered_url, params: search_params.to_json, headers: json_headers
            expect(response.code).to eq("201")
            expect(json_result).to match_hash_indifferently target_result.merge(state: "with_user")
          end
        end
      end
      context "state: impounded" do
        let(:target_result) { {registered: true, claimed: false, can_edit: false, state: "impounded", authorized_bike_id: nil} }
        it "returns impounded for impounded statuses" do
          %w[unregistered_parking_notification status_abandoned status_impounded].each do |status|
            bike.update_column :status, status
            expect(bike.reload.status).to eq status
            post check_if_registered_url, params: search_params.to_json, headers: json_headers
            expect(response.code).to eq("201")
            expect(json_result).to match_hash_indifferently target_result
          end
        end
      end
      context "state: transferred" do
        let(:target_result) { {registered: true, claimed: false, can_edit: false, state: "transferred", authorized_bike_id: nil} }
        it "returns target" do
          ownership = bike.current_ownership
          BikeServices::Updator.new(user: ownership.user, bike: bike, permitted_params: {bike: {owner_email: "newemail@example.com"}}.as_json).update_ownership
          expect(ownership.reload.current).to be_falsey
          expect(bike.reload.current_ownership.id).to_not eq ownership.id
          expect(bike.reload.owner_email).to eq "newemail@example.com"
          expect(bike.reload.authorized?(user)).to be_falsey
          post check_if_registered_url, params: search_params.to_json, headers: json_headers
          expect(response.code).to eq("201")
          expect(json_result).to match_hash_indifferently target_result
        end
      end
      context "state: removed" do
        let(:target_result) { {registered: false, claimed: false, can_edit: false, state: "removed", authorized_bike_id: nil} }
        it "returns target" do
          bike.delete
          post check_if_registered_url, params: search_params.to_json, headers: json_headers
          expect(response.code).to eq("201")
          expect(json_result).to match_hash_indifferently target_result
        end
      end
    end
  end

  describe "create" do
    let!(:token) { create_doorkeeper_token(scopes: "read_bikes write_bikes") }
    let(:bike_sticker) { FactoryBot.create(:bike_sticker) }
    before { FactoryBot.create(:wheel_size, iso_bsd: 559) }

    context "no token" do
      let(:token) { nil }
      it "responds with 401" do
        post "/api/v3/bikes", params: bike_attrs.to_json
        expect(response.code).to eq("401")
      end
    end

    context "without write_bikes scope" do
      let!(:token) { create_doorkeeper_token(scopes: "read_bikes") }
      it "fails" do
        post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json, headers: json_headers
        expect(response.code).to eq("403")
      end
    end

    context "unconfirmed user" do
      let(:user) { FactoryBot.create(:user) }
      let!(:token) { create_doorkeeper_token(scopes: "read_bikes write_bikes unconfirmed") }
      it "fails" do
        expect(user.unconfirmed?).to be_truthy
        expect(token.resource_owner_id).to eq user.id
        post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json, headers: json_headers
        expect(response.code).to eq("403")
      end
    end

    context "with a phone instead of an email" do
      let(:phone) { "1112224444" }
      let(:phone_bike) { bike_attrs.merge(owner_email: phone, owner_email_is_phone_number: true) }
      it "creates" do
        expect {
          post "/api/v3/bikes?access_token=#{token.token}", params: phone_bike.to_json, headers: json_headers
          pp json_result unless json_result["bike"].present?
        }.to change(Bike, :count).by 1
        expect(json_result[:claim_url]).to match(/t=/)

        bike_result = json_result["bike"]
        bike = Bike.last
        expect(bike_result[:id]).to eq bike.id
        expect(bike.phone_registration?).to be_truthy
        expect(bike.owner_email).to eq phone
        expect(bike.phone).to eq phone
        expect(bike.current_ownership.phone_registration?).to be_truthy
        expect(bike.current_ownership.calculated_send_email).to be_falsey
        expect(bike.current_ownership.doorkeeper_app_id).to eq doorkeeper_app.id
      end
      context "matching phone bike already registered" do
        let(:bike) { FactoryBot.create(:bike, :phone_registration, owner_email: phone, serial_number: phone_bike[:serial], manufacturer: manufacturer) }
        let!(:ownership) { FactoryBot.create(:ownership, owner_email: phone, is_phone: true, creator: user, bike: bike) }
        it "returns that bike" do
          bike.reload
          expect(user.authorized?(bike)).to be_truthy
          expect(bike.phone_registration?).to be_truthy
          expect(bike.current_ownership.phone_registration?).to be_truthy
          expect {
            post "/api/v3/bikes?access_token=#{token.token}", params: phone_bike.to_json, headers: json_headers
          }.to_not change(Bike, :count)
          expect(json_result[:claim_url]).to be_present
          expect(json_result[:claim_url]).to_not match(/t=/)

          bike_result = json_result["bike"]
          expect(bike_result["id"]).to eq bike.id
          expect(bike_result.to_s).to_not match(phone)
          expect(bike_result.to_s).to_not match(bike.owner_email)
        end
      end
      context "matching bike for user with phone" do
        let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: user, serial_number: phone_bike[:serial], manufacturer: manufacturer) }
        it "returns that bike" do
          user.update(phone: phone)
          user.reload
          bike.reload
          expect(user.authorized?(bike)).to be_truthy
          expect(bike.phone_registration?).to be_falsey
          expect(bike.current_ownership.phone_registration?).to be_falsey
          expect {
            post "/api/v3/bikes?access_token=#{token.token}", params: phone_bike.to_json, headers: json_headers
          }.to_not change(Bike, :count)

          bike_result = json_result["bike"]
          expect(bike_result["id"]).to eq bike.id
          expect(bike_result.to_s).to_not match(phone)
          expect(bike_result.to_s).to_not match(bike.owner_email)
        end
      end
    end

  #   context "given a matching pre-existing bike record" do
  #     context "if the POSTer is authorized to update" do
  #       it "does not create a new record" do
  #         user_email = FactoryBot.create(:user_email, user: user, email: "something@stuff.com", confirmation_token: "fake")
  #         user_email.reload
  #         expect(user_email.confirmed?).to be_falsey
  #         post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.merge(owner_email: user.email).to_json, headers: json_headers

  #         expect(response.status).to eq(201)
  #         expect(response.status_message).to eq("Created")
  #         bike1_result = json_result["bike"]
  #         post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.merge(owner_email: "something@stuff.com").to_json, headers: json_headers
  #         bike2_result = json_result["bike"]
  #         expect(response.status).to eq(302)
  #         expect(response.status_message).to eq("Found")
  #         expect(bike1_result["id"]).to eq(bike2_result["id"])
  #         bike = Bike.find bike1_result["id"]
  #         expect(bike.owner_email).to eq user.email
  #       end
  #       it "updates the pre-existing record" do
  #         expect(bike_sticker.reload.bike_sticker_updates.count).to eq 0
  #         old_color = FactoryBot.create(:color, name: "old_color")
  #         new_color = FactoryBot.create(:color, name: "new_color")
  #         old_manufacturer = FactoryBot.create(:manufacturer, name: "old_manufacturer")
  #         old_wheel_size = FactoryBot.create(:wheel_size, name: "old_wheel_size", iso_bsd: 10)
  #         new_rear_wheel_size = FactoryBot.create(:wheel_size, name: "new_rear_wheel_size", iso_bsd: 11)
  #         new_front_wheel_size = FactoryBot.create(:wheel_size, name: "new_front_wheel_size", iso_bsd: 12)
  #         old_cycle_type = CycleType.new("unicycle")
  #         old_year = 1969
  #         new_year = 2001
  #         bike1 = FactoryBot.create(
  #           :bike,
  #           creator: user,
  #           owner_email: user.email,
  #           year: old_year,
  #           manufacturer: old_manufacturer,
  #           primary_frame_color: old_color,
  #           cycle_type: old_cycle_type.id,
  #           rear_wheel_size: old_wheel_size,
  #           front_wheel_size: old_wheel_size,
  #           rear_tire_narrow: false,
  #           frame_material: "aluminum"
  #         )
  #         ownership = FactoryBot.create(:ownership, bike: bike1, creator: user, owner_email: user.email)

  #         bike_attrs = {
  #           serial: bike1.serial_number,
  #           manufacturer: old_manufacturer.name,
  #           rear_tire_narrow: true,
  #           front_wheel_bsd: new_front_wheel_size.iso_bsd,
  #           rear_wheel_bsd: new_rear_wheel_size.iso_bsd,
  #           propulsion_type_slug: "hand-pedal",
  #           color: new_color.name,
  #           year: new_year,
  #           owner_email: user.email,
  #           frame_material: "steel",
  #           bike_sticker: bike_sticker.code.downcase,
  #           cycle_type_name: "cargo tricycle (front storage)"
  #         }
  #         post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json,
  #           headers: json_headers.merge('X-IOS-VERSION' => 1.7)
  #         bike_response = json_result["bike"]
  #         expect(bike_response["id"]).to eq(bike1.id)
  #         expect(bike_response["serial"]).to eq(bike1.serial_display)
  #         expect(bike_response["year"]).to eq(new_year)
  #         expect(bike_response["frame_colors"].first).to eq(new_color.name)
  #         expect(bike_response["type_of_cycle"]).to eq("Cargo Tricycle (front storage)")
  #         expect(bike_response["manufacturer_id"]).to eq(old_manufacturer.id)
  #         expect(bike_response["front_wheel_size_iso_bsd"]).to eq(new_front_wheel_size.iso_bsd)
  #         expect(bike_response["rear_wheel_size_iso_bsd"]).to eq(new_rear_wheel_size.iso_bsd)
  #         expect(bike_response["rear_tire_narrow"]).to eq(true)
  #         expect(bike_response["frame_material_slug"]).to eq("steel")
  #         expect(bike_response["cycle_type_slug"]).to eq "cargo-trike"
  #         expect(bike_response["propulsion_type_slug"]).to eq "hand-pedal"

  #         expect(bike1.reload.ownerships.count).to eq 1
  #         expect(bike1.current_ownership&.id).to eq ownership.id
  #         expect(ownership.reload.doorkeeper_app_id).to eq doorkeeper_app.id
  #         expect(ownership.ios_version).to eq "1.7"

  #         bike_sticker.reload
  #         expect(bike_sticker.claimed?).to be_truthy
  #         expect(bike_sticker.bike_id).to eq bike1.id
  #         expect(bike_sticker.organization_id).to be_blank
  #         expect(bike_sticker.secondary_organization_id).to be_blank
  #         expect(bike_sticker.bike_sticker_updates.count).to eq 1
  #         bike_sticker_update = bike_sticker.bike_sticker_updates.first
  #         expect(bike_sticker_update.organization_id).to be_blank
  #         expect(bike_sticker_update.creator_kind).to eq "creator_user"
  #       end
  #     end

  #     context "if the matching bike is unclaimed" do
  #       it "updates if the submitting org is the creation org" do
  #         bike = FactoryBot.create(:bike_organized)
  #         FactoryBot.create(:ownership, creator: bike.creator, bike: bike)
  #         FactoryBot.create(:organization_role_claimed, user: user, organization: bike.creation_organization)

  #         bike_attrs = {
  #           serial: bike.serial_display,
  #           manufacturer: bike.manufacturer.name,
  #           color: color.name,
  #           year: bike.year,
  #           owner_email: bike.owner_email
  #         }
  #         post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json, headers: json_headers

  #         returned_bike = json_result["bike"]
  #         expect(response.status).to eq(302)
  #         expect(response.status_message).to eq("Found")
  #         expect(returned_bike["id"]).to eq(bike.id)
  #       end

  #       it "creates a new record if the submitting org isn't the creation org" do
  #         bike = FactoryBot.create(:bike_organized)
  #         FactoryBot.create(:ownership, creator: bike.creator, bike: bike)
  #         FactoryBot.create(:organization_role_claimed, user: user)

  #         bike_attrs = {
  #           serial: bike.serial_display,
  #           manufacturer: bike.manufacturer.name,
  #           color: color.name,
  #           year: bike.year,
  #           owner_email: bike.owner_email
  #         }
  #         post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json, headers: json_headers

  #         returned_bike = json_result["bike"]
  #         expect(response.status).to eq(201)
  #         expect(response.status_message).to eq("Created")
  #         expect(returned_bike["id"]).to_not eq(bike.id)
  #       end
  #     end

  #     context "if the matching bike is claimed" do
  #       let(:can_edit_claimed) { true }
  #       let(:bike) { FactoryBot.create(:bike_organized, can_edit_claimed: can_edit_claimed) }
  #       let!(:ownership) { FactoryBot.create(:ownership_claimed, creator: bike.creator, bike: bike) }
  #       let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user: user, organization: bike.creation_organization) }
  #       let(:bike_attrs) do
  #         {
  #           serial: bike.serial_display,
  #           manufacturer: bike.manufacturer.name,
  #           color: color.name,
  #           year: "2012",
  #           bike_sticker: "#{bike_sticker.code}  ",
  #           owner_email: bike.owner_email
  #         }
  #       end
  #       it "updates" do
  #         bike_sticker.claim(bike: bike, user: FactoryBot.create(:superuser))
  #         expect(bike_sticker.reload.bike_sticker_updates.count).to eq 1
  #         expect(bike.year).to_not eq 2012
  #         expect {
  #           post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json, headers: json_headers
  #         }.to_not change(Bike, :count)

  #         returned_bike = json_result["bike"]
  #         expect(response.status).to eq(302)
  #         expect(response.status_message).to eq "Found"
  #         expect(returned_bike["id"]).to eq bike.id
  #         expect(returned_bike["year"]).to eq 2012
  #         bike.reload
  #         expect(bike.year).to eq 2012
  #         # It doesn't reclaim sticker
  #         expect(bike_sticker.reload.bike_sticker_updates.count).to eq 1
  #       end
  #       context "can_edit_claimed false" do
  #         let(:can_edit_claimed) { false }
  #         it "creates a new bike" do
  #           expect(bike.year).to_not eq 2012
  #           expect {
  #             post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json, headers: json_headers
  #             pp json_result unless json_result["bike"].present?
  #           }.to change(Bike, :count).by 1

  #           returned_bike = json_result["bike"]
  #           expect(response.status).to eq(201)
  #           expect(response.status_message).to eq "Created"
  #           expect(returned_bike["id"]).to_not eq bike.id
  #           bike.reload
  #           expect(bike.year).to_not eq 2012
  #         end
  #       end
  #     end
  #   end

  #   context "given a bike with a pre-existing match by a normalized serial number" do
  #     it "responds with the match instead of creating a duplicate" do
  #       bike_attrs = {
  #         serial: "serial-Ol",
  #         manufacturer: manufacturer.name,
  #         color: color.name,
  #         year: "1969",
  #         owner_email: "bike-serial-01@examples.com"
  #       }
  #       post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json, headers: json_headers

  #       expect(response.status).to eq(201)
  #       expect(response.status_message).to eq("Created")
  #       bike1 = json_result["bike"]

  #       bike_attrs = bike_attrs.merge(serial: "serial-01")
  #       post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json, headers: json_headers

  #       bike2 = json_result["bike"]
  #       expect(response.status).to eq(302)
  #       expect(response.status_message).to eq("Found")
  #       expect(bike1["id"]).to eq(bike2["id"])
  #     end
  #   end

  #   context "given a bike with a pre-existing match by a normalized email" do
  #     it "responds with the match instead of creating a duplicate" do
  #       bike_attrs = {
  #         serial: "serial-01",
  #         manufacturer: manufacturer.name,
  #         color: color.name,
  #         year: "1969",
  #         owner_email: "bike-serial-01@example.com"
  #       }
  #       post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json, headers: json_headers

  #       expect(response.status).to eq(201)
  #       expect(response.status_message).to eq("Created")
  #       bike1 = json_result["bike"]

  #       bike_attrs = bike_attrs.merge(owner_email: "  bike-serial-01@example.com  ")
  #       post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json, headers: json_headers

  #       bike2 = json_result["bike"]
  #       expect(response.status).to eq(302)
  #       expect(response.status_message).to eq("Found")
  #       expect(bike1["id"]).to eq(bike2["id"])
  #     end
  #   end

  #   context "given a bike with a pre-existing match by an owning user's secondary email" do
  #     it "responds with the match instead of creating a duplicate" do
  #       user.user_emails.create(email: "secondary-email@example.com")
  #       bike = FactoryBot.create(:ownership, user: user).bike

  #       bike_attrs = {
  #         serial: bike.serial_display,
  #         manufacturer: bike.manufacturer.name,
  #         color: color.name,
  #         year: bike.year,
  #         owner_email: user.secondary_emails.first
  #       }
  #       post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json, headers: json_headers

  #       returned_bike = json_result["bike"]
  #       expect(response.status).to eq(302)
  #       expect(response.status_message).to eq("Found")
  #       expect(returned_bike["id"]).to eq(bike.id)
  #     end
  #   end

  #   context "given a bike with a pre-existing match by serial" do
  #     let!(:bike) { FactoryBot.create(:bike, :with_ownership, creator: user) }
  #     let(:bike_attrs) do
  #       {
  #         serial: bike.serial_display,
  #         manufacturer: bike.manufacturer.name,
  #         color: color.name,
  #         year: bike.year,
  #         owner_email: bike.owner_email
  #       }
  #     end
  #     it "creates a new bike if the match has a different owner" do
  #       post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.merge(owner_email: "some-other-owner@example.com").to_json, headers: json_headers

  #       returned_bike = json_result["bike"]
  #       expect(response.status).to eq(201)
  #       expect(response.status_message).to eq("Created")
  #       expect(returned_bike["id"]).to_not eq(bike.id)
  #     end
  #     context "no_duplicate" do
  #       it "doesn't create a duplicate" do
  #         post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.merge(no_duplicate: true).to_json, headers: json_headers

  #         returned_bike = json_result["bike"]
  #         expect(response.status).to eq(302)
  #         expect(response.status_message).to eq("Found")
  #         expect(returned_bike["id"]).to eq(bike.id)
  #       end
  #     end
  #   end

  #   it "creates a non example bike, with components" do
  #     manufacturer2 = FactoryBot.create(:manufacturer)
  #     FactoryBot.create(:ctype, name: "wheel")
  #     FactoryBot.create(:ctype, name: "Headset")
  #     front_gear_type = FactoryBot.create(:front_gear_type)
  #     handlebar_type_slug = "bmx"
  #     components = [
  #       {
  #         manufacturer: manufacturer2.name,
  #         year: "1999",
  #         component_type: "headset",
  #         description: "yeah yay!",
  #         serial_number: "69",
  #         model: "Richie rich"
  #       },
  #       {
  #         manufacturer: "BLUE TEETH",
  #         front_or_rear: "Both",
  #         component_type: "wheel"
  #       }
  #     ]
  #     bike_attrs.merge!(components: components,
  #       front_gear_type_slug: front_gear_type.slug,
  #       handlebar_type_slug: handlebar_type_slug,
  #       is_for_sale: true,
  #       propulsion_type_slug: "pedal-assist",
  #       is_bulk: true,
  #       is_new: true,
  #       extra_registration_number: "serial:#{bike_attrs[:serial]}",
  #       is_pos: true,
  #       bike_sticker: bike_sticker.code.downcase,
  #       external_image_urls: ["https://files.bikeindex.org/email_assets/bike_photo_placeholder.png"],
  #       description: "<svg/onload=alert(document.cookie)>")
  #     expect {
  #       post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json, headers: json_headers
  #     }.to change(Email::OwnershipInvitationJob.jobs, :size).by(1)
  #     expect(response.code).to eq("201")
  #     result = json_result["bike"]
  #     expect(result["serial"]).to eq(bike_attrs[:serial])
  #     expect(result["manufacturer_name"]).to eq(bike_attrs[:manufacturer])
  #     bike = Bike.find(result["id"])
  #     expect(bike.example).to be_falsey
  #     expect(bike.is_for_sale).to be_truthy
  #     expect(bike.frame_material).to eq(bike_attrs[:frame_material])
  #     expect(bike.serial_unknown?).to be_falsey
  #     expect(bike.serial_normalized).to eq "69 N0N EXAMP1E"
  #     expect(bike.components.count).to eq(3)
  #     expect(bike.components.pluck(:manufacturer_id).include?(manufacturer2.id)).to be_truthy
  #     expect(bike.components.pluck(:ctype_id).uniq.count).to eq(2)
  #     expect(bike.front_gear_type).to eq(front_gear_type)
  #     expect(bike.handlebar_type).to eq(handlebar_type_slug)
  #     expect(bike.extra_registration_number).to be_nil
  #     expect(bike.external_image_urls).to eq(["https://files.bikeindex.org/email_assets/bike_photo_placeholder.png"])
  #     expect(bike.propulsion_type).to eq "pedal-assist"
  #     ownership = bike.current_ownership
  #     expect(ownership.pos?).to be_truthy
  #     expect(ownership.is_new).to be_truthy
  #     expect(ownership.bulk?).to be_falsey
  #     expect(ownership.organization_id).to be_blank
  #     expect(ownership.origin).to eq "api_v3"

  #     # We return things will alert if they're written directly to the dom - worth noting, since it might be a problem
  #     expect(result["description"]).to eq ""
  #     expect(bike.description).to eq ""
  #   end

  #   it "doesn't send an email" do
  #     ActionMailer::Base.deliveries = []
  #     post "/api/v3/bikes?access_token=#{token.token}",
  #       params: bike_attrs.merge(no_notify: true, extra_registration_number: " ").to_json,
  #       headers: json_headers
  #     Email::OwnershipInvitationJob.drain
  #     expect(ActionMailer::Base.deliveries).to be_empty
  #     expect(response.code).to eq("201")
  #     bike = Bike.last
  #     expect(bike.extra_registration_number).to be_nil
  #   end

  #   it "creates an example bike" do
  #     ActionMailer::Base.deliveries = []
  #     post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.merge(test: true).to_json, headers: json_headers
  #     Email::OwnershipInvitationJob.drain
  #     expect(ActionMailer::Base.deliveries).to be_empty
  #     expect(response.code).to eq("201")
  #     result = json_result["bike"]
  #     expect(result["serial"]).to eq(bike_attrs[:serial])
  #     expect(result["manufacturer_name"]).to eq(bike_attrs[:manufacturer])
  #     bike = Bike.unscoped.find(result["id"])
  #     # expect(bike.current_ownership.origin).to eq 'api_v3'
  #     expect(bike.example).to be_truthy
  #     expect(bike.is_for_sale).to be_falsey
  #   end

  #   context "with extra_registration_number" do
  #     let(:bike_attrs) do
  #       {
  #         serial: "made_without_serial",
  #         extra_registration_number: "Another Serial ",
  #         manufacturer: manufacturer.name,
  #         color: color.name,
  #         owner_email: user.email
  #       }
  #     end
  #     it "registers with extra_registration_number" do
  #       post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json, headers: json_headers
  #       bike = Bike.last
  #       bike_response = json_result["bike"]
  #       expect(bike_response["id"]).to eq(bike.id)
  #       expect(bike_response["serial"]).to eq "Made without serial"
  #       expect(bike_response["frame_colors"].first).to eq(color.name)
  #       expect(bike_response["manufacturer_id"]).to eq(manufacturer.id)
  #       expect(bike_response["extra_registration_number"]).to eq "Another Serial"
  #       expect(bike.made_without_serial?).to be_truthy
  #       expect(bike.serial_normalized).to be_blank
  #       expect(bike.extra_registration_number).to eq "Another Serial"
  #     end
  #   end

  #   context "without color" do
  #     it "fails" do
  #       expect {
  #         post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.except(:color).to_json, headers: json_headers
  #         expect(json_result["error"]).to eq "color is missing"
  #       }.to_not change(Bike, :count)
  #     end
  #   end

  #   context "with non case matching primary_frame_color and non-matching color" do
  #     let!(:silver) { FactoryBot.create(:color, name: "Silver, gray or bare metal") }
  #     let!(:purple) { FactoryBot.create(:color, name: "Purple") }
  #     let(:purple_attrs) { bike_attrs.merge(color: "Chaotic Eggplant", primary_frame_color: "Purple", secondary_frame_color: "pURPLE ", tertiary_frame_color: "silver") }
  #     it "registers" do
  #       post "/api/v3/bikes?access_token=#{token.token}", params: purple_attrs.to_json, headers: json_headers
  #       bike = Bike.last
  #       bike_response = json_result["bike"]
  #       expect(bike_response["id"]).to eq(bike.id)
  #       expect(bike_response["serial"]).to eq bike_attrs[:serial]
  #       expect(bike_response["frame_colors"]).to eq(["Purple", "Purple", silver.name])
  #       expect(bike_response["paint_description"]).to eq("Chaotic Eggplant")
  #       expect(bike_response["manufacturer_id"]).to eq(manufacturer.id)
  #       expect(bike.paint.name).to eq "chaotic eggplant"
  #     end
  #   end

  #   context "organization" do
  #     let(:organization) { FactoryBot.create(:organization) }
  #     it "creates a stolen bike through an organization and uses the passed phone", :flaky do
  #       user.update_attribute :phone, "0987654321"
  #       FactoryBot.create(:organization_role, user: user, organization: organization)
  #       FactoryBot.create(:state_new_york)
  #       date_stolen = 1357192800
  #       bike_attrs[:serial] = "unknown"
  #       bike_attrs[:stolen_record] = {
  #         phone: "1234567890",
  #         date_stolen: date_stolen,
  #         theft_description: "This bike was stolen and that's no fair.",
  #         country: "US",
  #         city: "New York",
  #         street: "278 Broadway",
  #         zipcode: "10007",
  #         show_address: true,
  #         state: "NY",
  #         police_report_number: "99999999",
  #         police_report_department: "New York"
  #       }
  #       expect {
  #         post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json, headers: json_headers
  #       }.to change(Email::OwnershipInvitationJob.jobs, :size).by(1)
  #       expect(json_result).to include("bike")
  #       expect(json_result["bike"]["serial"]).to eq "Unknown"
  #       expect(json_result["bike"]["manufacturer_name"]).to eq(bike_attrs[:manufacturer])
  #       expect(json_result["bike"]["stolen_record"]["date_stolen"]).to eq(date_stolen)
  #       bike = Bike.find(json_result["bike"]["id"])
  #       expect(bike.creation_organization).to eq(organization)
  #       expect(bike.bike_organizations.count).to eq 1
  #       expect(bike.serial_unknown?).to be_truthy
  #       expect(bike.serial_normalized).to be_blank
  #       expect(bike.status).to eq "status_stolen"
  #       bike_organization = bike.bike_organizations.first
  #       expect(bike_organization.organization_id).to eq organization.id
  #       expect(bike_organization.can_edit_claimed).to be_truthy
  #       expect(bike.current_ownership.origin).to eq "api_v3"
  #       expect(bike.current_ownership.organization).to eq organization
  #       expect(bike.current_stolen_record_id).to be_present
  #       expect(bike.current_stolen_record.police_report_number).to eq(bike_attrs[:stolen_record][:police_report_number])
  #       expect(bike.current_stolen_record.phone).to eq("1234567890")
  #       expect(bike.current_stolen_record.show_address).to be_falsey
  #     end
  #   end

  #   it "does not register a stolen bike unless attrs are present" do
  #     bike_attrs[:stolen_record] = {
  #       phone: "",
  #       theft_description: "I was away for a little bit and suddenly the bike was gone",
  #       city: "Chicago"
  #     }
  #     expect {
  #       post "/api/v3/bikes?access_token=#{token.token}", params: bike_attrs.to_json, headers: json_headers
  #     }.to change(Email::OwnershipInvitationJob.jobs, :size).by(1)
  #     expect(json_result).to include("bike")
  #     expect(json_result["bike"]["serial"]).to eq(bike_attrs[:serial])
  #     expect(json_result["bike"]["manufacturer_name"]).to eq(bike_attrs[:manufacturer])
  #     expect(json_result["bike"]["stolen_record"]["date_stolen"]).to be_within(1).of Time.current.to_i
  #     bike = Bike.find(json_result["bike"]["id"])
  #     expect(bike.creation_organization).to be_blank
  #     expect(bike.current_ownership.origin).to eq "api_v3"
  #     expect(bike.status_stolen?).to be_truthy
  #     expect(bike.current_stolen_record_id).to be_present
  #     expect(bike.current_stolen_record.police_report_number).to be_nil
  #     expect(bike.current_stolen_record.phone).to be_nil
  #     expect(bike.current_stolen_record.show_address).to be_falsey
  #     expect(bike.current_stolen_record.theft_description).to eq "I was away for a little bit and suddenly the bike was gone"
  #   end
  # end

  # describe "create v2_accessor" do
  #   let(:organization) { FactoryBot.create(:organization) }
  #   let(:email) { "fun_times@examples.com" }
  #   let!(:tokenized_url) { "/api/v3/bikes?access_token=#{v2_access_token.token}" }
  #   before { FactoryBot.create(:wheel_size, iso_bsd: 559) }

  #   context "with membership" do
  #     before do
  #       FactoryBot.create(:organization_role, user: user, organization: organization, role: "admin")
  #       organization.save
  #     end

  #     context "duplicated serial" do
  #       context "matching email" do
  #         it "returns existing bike if authorized by organization" do
  #           bike = FactoryBot.create(:bike, serial_number: bike_attrs[:serial], owner_email: email, manufacturer: manufacturer)
  #           bike.organizations << organization
  #           bike.save
  #           ownership = FactoryBot.create(:ownership, bike: bike, owner_email: email)

  #           expect(ownership.claimed).to be_falsey
  #           ActionMailer::Base.deliveries = []
  #           Sidekiq::Job.clear_all
  #           expect(bike.reload.authorized?(user)).to be_truthy
  #           expect {
  #             post tokenized_url, params: bike_attrs.to_json, headers: json_headers
  #           }.to change(Bike, :count).by 0

  #           result = json_result["bike"]
  #           expect(response.status).to eq(302)
  #           expect(response.status_message).to eq("Found")
  #           expect(result["id"]).to eq bike.id

  #           Email::OwnershipInvitationJob.drain
  #           expect(ActionMailer::Base.deliveries).to be_empty
  #         end
  #       end

  #       context "non-matching email" do
  #         let(:email) { "another_email@example.com" }
  #         it "creates a bike for organization with v3_accessor, doesn't send email because skip_email", :flaky do
  #           organization.update_attribute :enabled_feature_slugs, ["skip_ownership_email"]
  #           bike = FactoryBot.create(:bike, serial_number: bike_attrs[:serial], owner_email: email)
  #           ownership = FactoryBot.create(:ownership, bike: bike, owner_email: email)
  #           expect(ownership.claimed).to be_falsey
  #           ActionMailer::Base.deliveries = []
  #           Sidekiq::Job.clear_all
  #           expect {
  #             post tokenized_url, params: bike_attrs.to_json, headers: json_headers
  #             pp json_result unless json_result["bike"].present?
  #           }.to change(Bike, :count).by 1
  #           result = json_result["bike"]

  #           expect(response.code).to eq("201")
  #           bike = Bike.find(result["id"])
  #           expect(bike.creation_organization).to eq(organization)
  #           expect(bike.creator).to eq(user)
  #           expect(bike.secondary_frame_color).to be_nil
  #           expect(bike.rear_wheel_size.iso_bsd).to eq 559
  #           expect(bike.front_wheel_size.iso_bsd).to eq 559
  #           expect(bike.rear_tire_narrow).to be_truthy
  #           expect(bike.front_tire_narrow).to be_truthy
  #           # expect(bike.current_ownership.origin).to eq 'api_v3'
  #           expect(bike.current_ownership.organization).to eq organization
  #           Email::OwnershipInvitationJob.drain
  #           expect(ActionMailer::Base.deliveries).to be_empty
  #         end
  #       end
  #     end

  #     context "organization_pre_registration" do
  #       let(:organization) { FactoryBot.create(:organization, :with_auto_user, kind: "bike_shop") }
  #       let(:email) { auto_user.email }
  #       before { Sidekiq::Testing.inline! }
  #       after { Sidekiq::Testing.fake! }
  #       it "creates, update with email includes organization", :flaky do
  #         expect(auto_user.confirmed?).to be_truthy
  #         expect(auto_user.id).to_not eq user.id
  #         ActionMailer::Base.deliveries = []
  #         Sidekiq::Job.clear_all
  #         expect(Bike.count).to eq 0

  #         post tokenized_url,
  #           params: bike_attrs.merge(no_duplicate: true).to_json,
  #           headers: json_headers

  #         expect(Bike.count).to eq 1
  #         expect(response.code).to eq("201")

  #         bike = Bike.find(json_result.dig("bike", "id"))
  #         expect(bike.creation_organization&.id).to eq(organization.id)
  #         expect(bike.creator&.id).to eq(auto_user.id)
  #         expect(bike.secondary_frame_color).to be_nil
  #         expect(bike.pos?).to be_falsey
  #         expect(bike.owner_email).to eq email
  #         ownership = bike.current_ownership
  #         expect(ownership.new_registration?).to be_truthy
  #         expect(ownership.send_email).to be_truthy
  #         expect(ownership.owner_email).to eq email
  #         expect(ownership.creator_id).to eq auto_user.id
  #         expect(ownership.user_id).to eq auto_user.id
  #         expect(ownership.organization_pre_registration?).to be_truthy
  #         Email::OwnershipInvitationJob.drain
  #         expect(ActionMailer::Base.deliveries).to_not be_empty
  #         mail = ActionMailer::Base.deliveries.last
  #         expect(mail.subject).to eq("#{organization.name} Bike Index registration successful")
  #         expect(mail.reply_to).to eq([email])
  #         expect(mail.tag).to eq "finished_registration"
  #         expect(mail.body.encoded).to_not match "supported by"

  #         # Updating to send to a new owner, the new ownership is through the organization
  #         # (needs to use a new token)
  #         put "/api/v3/bikes/#{bike.id}?access_token=#{v2_access_token.token}",
  #           params: {owner_email: "newperson@stuff.com"}.to_json,
  #           headers: json_headers

  #         expect(response.status).to eq(200)
  #         expect(bike.ownerships.count).to eq 2
  #         ownership2 = bike.reload.current_ownership
  #         expect(ownership2.id).to_not eq ownership.id
  #         expect(ownership2.owner_email).to eq "newperson@stuff.com"
  #         expect(ownership2.creator_id).to eq user.id
  #         expect(ownership2.origin).to eq "transferred_ownership"
  #         expect(ownership2.new_registration?).to be_truthy
  #         expect(ownership2.organization_pre_registration?).to be_falsey
  #         expect(ownership2.organization_id).to eq organization.id

  #         mail2 = ActionMailer::Base.deliveries.last
  #         expect(mail2.subject).to eq("Confirm your #{organization.name} Bike Index registration")
  #         expect(mail2.reply_to).to eq([email])
  #         expect(mail2.tag).to eq "finished_registration"
  #         expect(mail2.body.encoded).to_not match "supported by"
  #       end
  #     end

  #     # This is how it actually occurs in the real world.
  #     context "v2_accessor is not the application owner" do
  #       let(:other_user) { FactoryBot.create(:user_confirmed) }
  #       let(:v2_access_id) { ENV["V2_ACCESSOR_ID"] = other_user.id.to_s }
  #       it "v2_accessor", :flaky do
  #         expect(v2_access_token.resource_owner_id).to eq other_user.id
  #         expect(v2_access_token.resource_owner_id).to_not eq user.id
  #         expect(v2_access_token.application.owner.admin_of?(organization)).to be_truthy
  #         expect(other_user.admin_of?(organization)).to be_falsey
  #         post tokenized_url, params: bike_attrs.to_json, headers: json_headers
  #         expect(response.code).to eq("201")
  #         bike = Bike.find(json_result.dig("bike", "id"))
  #         expect(bike.creation_organization).to eq(organization)
  #         expect(bike.creator).to eq(user)
  #         expect(bike.secondary_frame_color).to be_nil
  #         expect(bike.rear_wheel_size.iso_bsd).to eq 559
  #         expect(bike.front_wheel_size.iso_bsd).to eq 559
  #         expect(bike.rear_tire_narrow).to be_truthy
  #         expect(bike.front_tire_narrow).to be_truthy
  #         # expect(bike.current_ownership.origin).to eq 'api_v3'
  #         expect(bike.current_ownership.organization).to eq organization
  #         Email::OwnershipInvitationJob.drain
  #         expect(ActionMailer::Base.deliveries.count).to eq 1
  #       end
  #     end
  #   end

  #   it "fails to create a bike if the app owner isn't a member of the organization" do
  #     expect(user.has_organization_role?).to be_falsey
  #     post tokenized_url, params: bike_attrs.to_json, headers: json_headers
  #     expect(response.code).to eq("403")
  #     expect(json_result["error"].is_a?(String)).to be_truthy
  #     expect(json_result["error"]).to match(/permanent token/i)
  #     Email::OwnershipInvitationJob.drain
  #     expect(ActionMailer::Base.deliveries).to be_empty
  #   end
  # end

  # describe "create client credentials" do
  #   let(:client_credentials_token) do
  #     post "/oauth/token", params: {
  #       grant_type: "client_credentials",
  #       client_id: doorkeeper_app.uid,
  #       client_secret: doorkeeper_app.secret,
  #       scope: "write_bikes read_bikes"
  #     }
  #     expect(Doorkeeper::AccessToken.count).to eq 1
  #     Doorkeeper::AccessToken.last
  #   end
  #   let(:url) { "/api/v3/bikes?access_token=#{client_credentials_token.token}" }
  #   let(:organization) { FactoryBot.create(:organization, :with_auto_user, kind: "bike_manufacturer") }

  #   it "errors" do
  #     expect(client_credentials_token.reload.acceptable?(nil)).to be_truthy
  #     expect(application_owner.organizations.pluck(:id)).to eq([])
  #     post url, params: bike_attrs.except(:organization_slug).to_json, headers: json_headers
  #     expect(json_result[:error]).to match(/no user/i)
  #     expect(Bike.count).to eq 0
  #     # Posting with an organization doesn't help
  #     post url, params: bike_attrs.merge(no_duplicate: true).to_json, headers: json_headers
  #     expect(json_result[:error]).to match(/no user/i)
  #     expect(Bike.count).to eq 0
  #   end
  #   context "application creator is admin of organization", :flaky do
  #     let(:application_owner) { FactoryBot.create(:organization_admin, organization: organization) }

  #     it "creates" do
  #       expect(application_owner.reload.admin_of?(organization)).to be_truthy
  #       expect(client_credentials_token.application.owner.id).to_not eq auto_user.id
  #       post url, params: bike_attrs.merge(no_duplicate: true).to_json, headers: json_headers
  #       pp json_result unless json_result["bike"].present?

  #       bike = Bike.last
  #       expect(json_result.dig("bike", "id")).to eq bike.id
  #       expect(bike.creation_organization&.id).to eq(organization.id)
  #       expect(bike.creator&.id).to eq(auto_user.id)
  #       expect(bike.secondary_frame_color).to be_nil
  #       expect(bike.pos?).to be_falsey
  #       expect(bike.owner_email).to eq email
  #       ownership = bike.current_ownership
  #       expect(ownership.new_registration?).to be_truthy
  #       expect(ownership.send_email).to be_truthy
  #       expect(ownership.owner_email).to eq email
  #       expect(ownership.creator_id).to eq auto_user.id
  #       expect(ownership.organization_pre_registration?).to be_falsey

  #       expect(response.code).to eq("201")
  #       expect(Bike.count).to eq 1

  #       # It doesn't duplicate
  #       expect {
  #         post url, params: bike_attrs.merge(no_duplicate: true).to_json, headers: json_headers
  #         expect(json_result.dig("bike", "id")).to eq bike.id
  #       }.to_not change(Bike, :count)
  #     end
  #     context "application creator is auto_user of organization" do
  #       let(:application_owner) { auto_user }
  #       before { application_owner.organization_roles.first.update(role: "admin") }
  #       it "creates" do
  #         expect(application_owner.reload.admin_of?(organization)).to be_truthy
  #         expect(client_credentials_token.application.owner.id).to eq auto_user.id
  #         post url, params: bike_attrs.merge(no_duplicate: true).to_json, headers: json_headers
  #         bike = Bike.last
  #         expect(json_result.dig("bike", "id")).to eq bike.id
  #         expect(bike.creation_organization&.id).to eq(organization.id)
  #         expect(bike.creator&.id).to eq(auto_user.id)
  #         bike.current_ownership
  #       end
  #     end
  #     context "different organization" do
  #       let(:organization2) { FactoryBot.create(:organization) }
  #       it "fails" do
  #         expect(application_owner.reload.admin_of?(organization)).to be_truthy
  #         expect(application_owner.reload.admin_of?(organization2)).to be_falsey
  #         expect(client_credentials_token.application.owner.id).to eq application_owner.id
  #         post url, params: bike_attrs.merge(organization_slug: organization2.slug).to_json, headers: json_headers
  #         expect(json_result[:error]).to match(/organization/i)
  #         expect(Bike.count).to eq 0
  #       end
  #     end
  #     context "member - not admin" do
  #       let(:application_owner) { FactoryBot.create(:user, :with_organization, organization: organization) }
  #       it "fails" do
  #         expect(application_owner.reload.admin_of?(organization)).to be_falsey
  #         expect(client_credentials_token.application.owner.id).to eq application_owner.id
  #         post url, params: bike_attrs.to_json, headers: json_headers
  #         expect(json_result[:error]).to match(/organization/i)
  #         expect(Bike.count).to eq 0
  #       end
  #     end
  #   end
  # end

  # describe "update" do
  #   before do
  #     FactoryBot.create(:color, name: "Orange")
  #     Country.united_states
  #   end

  #   let(:params) do
  #     {
  #       year: 1975,
  #       serial_number: "XXX69XXX",
  #       description: "updated description",
  #       primary_frame_color: "orange",
  #       secondary_frame_color: "black",
  #       tertiary_frame_color: "orange",
  #       front_gear_type_slug: "2",
  #       rear_gear_type_slug: "3",
  #       handlebar_type_slug: "front"
  #     }
  #   end

  #   let(:url) { "/api/v3/bikes/#{bike.id}?access_token=#{token.token}" }
  #   let(:ownership) { FactoryBot.create(:ownership, creator_id: user.id) }
  #   let(:bike) { ownership.bike }
  #   let!(:token) { create_doorkeeper_token(scopes: "read_user read_bikes write_bikes") }

  #   it "doesn't update if user doesn't own the bike" do
  #     other_user = FactoryBot.create(:user)
  #     bike.current_ownership.update(user_id: other_user.id, claimed: true)
  #     allow_any_instance_of(Bike).to receive(:type).and_return("unicorn")

  #     put url, params: params.to_json, headers: json_headers

  #     expect(response.body.match("do not own that unicorn")).to be_present
  #     expect(response.code).to eq("403")
  #   end

  #   it "doesn't update if not in scope" do
  #     token.update_attribute :scopes, "public"

  #     put url, params: params.to_json, headers: json_headers

  #     expect(response.code).to eq("403")
  #     expect(response.body).to match(/oauth/i)
  #     expect(response.body).to match(/scope/i)
  #   end

  #   it "updates a bike, adds a stolen record, doesn't update locked attrs" do
  #     expect(bike.year).to be_nil
  #     expect(bike.primary_frame_color.name).to eq("Black")

  #     serial = bike.serial_number
  #     params[:stolen_record] = {
  #       city: "Chicago",
  #       phone: "1234567890",
  #       show_address: true,
  #       police_report_number: "999999"
  #     }
  #     params[:owner_email] = "foo@new_owner.com"
  #     params[:primary_frame_color] = "orange"

  #     expect {
  #       put url, params: params.to_json, headers: json_headers
  #     }.to change(Ownership, :count).by(1)

  #     expect(response.status).to eq(200)
  #     expect(bike.reload.year).to eq(params[:year])
  #     expect(bike.primary_frame_color&.name).to eq("Orange")
  #     expect(bike.serial_number).to eq(serial)
  #     expect(bike.status_stolen?).to be_truthy
  #     expect(bike.current_stolen_record.date_stolen.to_i).to be > Time.current.to_i - 10
  #     expect(bike.current_stolen_record.police_report_number).to eq("999999")
  #     expect(bike.current_stolen_record.show_address).to be_falsey
  #   end

  #   it "updates a bike, adds and removes components" do
  #     wheels = FactoryBot.create(:ctype, name: "Wheel")
  #     headsets = FactoryBot.create(:ctype, name: "Headset")
  #     mfg1 = FactoryBot.create(:manufacturer, name: "old manufacturer")
  #     mfg2 = FactoryBot.create(:manufacturer, name: "new manufacturer")
  #     comp = FactoryBot.create(:component, manufacturer: mfg1, bike: bike, ctype: headsets)
  #     comp2 = FactoryBot.create(:component, manufacturer: mfg1, bike: bike, ctype: wheels, serial_number: "old-serial")
  #     FactoryBot.create(:component)
  #     bike.reload
  #     expect(bike.components.count).to eq(2)

  #     components = [
  #       {
  #         manufacturer: mfg2.name,
  #         year: "1999",
  #         component_type: "HEADSET ", # Friendly find!
  #         description: "C-2",
  #         model: "Sram GXP Eagle"
  #       },
  #       {
  #         manufacturer: "BLUE TEETH",
  #         front_or_rear: "Rear",
  #         description: "C-3"
  #       },
  #       {
  #         id: comp.id,
  #         destroy: true
  #       },
  #       {
  #         id: comp2.id,
  #         manufacturer: mfg2.id,
  #         year: "1999",
  #         serial: "updated-serial",
  #         description: "C-1"
  #       }
  #     ]
  #     params[:is_for_sale] = true
  #     params[:components] = components

  #     expect {
  #       put url, params: params.to_json, headers: json_headers
  #     }.to change(Ownership, :count).by(0)

  #     expect(response.status).to eq(200)

  #     bike.reload
  #     expect(bike.is_for_sale).to be_truthy
  #     expect(bike.year).to eq(params[:year])

  #     components = bike.components.reload
  #     expect(components.count).to eq(3)
  #     expect(comp2.reload.year).to eq(1999)
  #     expect(components.map(&:component_model).compact).to eq(["Sram GXP Eagle"])

  #     manufacturers = components.map { |c| [c.description, c.manufacturer&.name] }.compact
  #     expect(manufacturers).to(match_array([["C-1", "new manufacturer"],
  #       ["C-2", "new manufacturer"],
  #       ["C-3", "Other"]]))

  #     serials = components.map { |c| [c.description, c.serial_number] }.compact
  #     expect(serials).to(match_array([["C-1", "updated-serial"],
  #       ["C-2", nil],
  #       ["C-3", nil]]))
  #   end

  #   it "doesn't remove components that aren't the bikes" do
  #     FactoryBot.create(:manufacturer)
  #     comp = FactoryBot.create(:component, bike: bike)
  #     not_urs = FactoryBot.create(:component)
  #     components = [
  #       {
  #         id: comp.id,
  #         year: 1999
  #       }, {
  #         id: not_urs.id,
  #         destroy: true
  #       }
  #     ]
  #     params[:components] = components

  #     put url, params: params.to_json, headers: json_headers

  #     expect(response.code).to eq("401")
  #     expect(response.headers["Content-Type"].match("json")).to be_present
  #     # response.headers['Access-Control-Allow-Origin'].should eq('*')
  #     # response.headers['Access-Control-Request-Method'].should eq('*')
  #     expect(bike.reload.components.reload.count).to eq(1)
  #     expect(bike.components.pluck(:year).first).to eq(1999) # Feature, not a bug?
  #     expect(not_urs.reload.id).to be_present
  #   end

  #   context "unclaimed bike" do
  #     let(:ownership) { FactoryBot.create(:ownership, owner_email: user.email, claimed: false) }
  #     it "claims a bike and updates if it should" do
  #       bike.reload
  #       expect(bike.year).to be_nil
  #       expect(bike.owner).not_to eq user
  #       expect(bike.creator).not_to eq user
  #       put url, params: params.to_json, headers: json_headers
  #       expect(response.code).to eq("200")
  #       expect(response.headers["Content-Type"].match("json")).to be_present
  #       expect(bike.reload.current_ownership.claimed).to be_truthy
  #       expect(bike.owner).to eq(user)
  #       expect(bike.year).to eq(params[:year])
  #     end
  #   end

  #   context "organization bike" do
  #     let(:organization) { FactoryBot.create(:organization) }
  #     let(:og_creator) { FactoryBot.create(:organization_user, organization: organization) }
  #     let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, creator: og_creator) }
  #     let(:ownership) { bike.ownerships.first }
  #     let(:user) { FactoryBot.create(:organization_user, organization: organization) }
  #     let(:params) { {year: 1999, external_image_urls: ["https://files.bikeindex.org/email_assets/logo.png"]} }
  #     let!(:token) { create_doorkeeper_token(scopes: "read_user read_bikes write_bikes") }
  #     it "permits updating" do
  #       bike.reload
  #       expect(bike.public_images.count).to eq 0
  #       expect(bike.owner).to_not eq(user)
  #       expect(bike.authorized_by_organization?(u: user)).to be_truthy
  #       expect(bike.authorized?(user)).to be_truthy
  #       expect(bike.claimed?).to be_falsey
  #       expect(bike.current_ownership.claimed?).to be_falsey
  #       put url, params: params.to_json, headers: json_headers
  #       expect(response.code).to eq("200")
  #       expect(response.headers["Content-Type"].match("json")).to be_present
  #       bike.reload
  #       expect(bike.claimed?).to be_falsey
  #       expect(bike.authorized_by_organization?(u: user)).to be_truthy
  #       expect(bike.reload.owner).to_not eq user
  #       expect(bike.year).to eq params[:year]
  #       expect(bike.external_image_urls).to eq([]) # Because we haven't created another bparam - this could change though
  #       expect(bike.public_images.count).to eq 1
  #     end
  #     context "updating email address to a new owner without an existing account" do
  #       before do
  #         bike.reload # Ensure it's established
  #         ActionMailer::Base.deliveries = []
  #         Sidekiq::Job.clear_all
  #         Sidekiq::Testing.inline!
  #       end
  #       after { Sidekiq::Testing.fake! }
  #       let(:new_email) { "newuser@example.com" }
  #       let(:bike_organization) { bike.bike_organizations.first }
  #       it "creates a new ownership, emails owner, permits organization editing until has been claimed" do
  #         expect(og_creator.reload.authorized?(organization)).to be_truthy
  #         expect(user.reload.authorized?(organization)).to be_truthy
  #         expect(og_creator.id).to_not eq user.id
  #         bike.reload
  #         expect(bike.bike_organizations.count).to eq 1
  #         expect(bike.public_images.count).to eq 0
  #         expect(bike.user).to be_blank
  #         expect(bike.owner).to_not eq(user)
  #         expect(bike.authorized_by_organization?(u: user)).to be_truthy
  #         expect(bike.authorized?(user)).to be_truthy
  #         expect(bike.authorized?(og_creator))
  #         expect(bike.claimed?).to be_falsey
  #         expect(bike.current_ownership.claimed?).to be_falsey
  #         expect(bike.current_ownership.doorkeeper_app_id).to be_blank
  #         expect(bike_organization.can_edit_claimed).to be_truthy
  #         expect {
  #           put url, params: {owner_email: "newuser@EXAMPLE.com "}.to_json,
  #             headers: json_headers.merge('X-iOS-Version' => '1.6.9')
  #         }.to change(Ownership, :count).by(1)
  #         expect(response.code).to eq("200")
  #         expect(response.headers["Content-Type"].match("json")).to be_present
  #         bike.reload
  #         ownership.reload
  #         expect(ownership.current?).to be_falsey
  #         expect(bike_organization.reload.can_edit_claimed).to be_truthy # Because the ownership hasn't been claimed yet
  #         expect(bike.owner_email).to eq new_email
  #         expect(bike.user).to be_blank
  #         expect(bike.claimed?).to be_falsey
  #         expect(bike.current_ownership.id).to_not eq ownership.id
  #         expect(bike.authorized?(user)).to be_truthy
  #         expect(bike.authorized?(og_creator)).to be_truthy
  #         expect(bike.authorized_by_organization?(u: og_creator)).to be_truthy
  #         current_ownership = bike.current_ownership
  #         expect(current_ownership.creator_id).to eq user.id
  #         expect(current_ownership.owner_email).to eq new_email
  #         expect(current_ownership.organization_id).to eq organization.id
  #         expect(current_ownership.initial?).to be_falsey
  #         expect(current_ownership.doorkeeper_app_id).to eq doorkeeper_app.id
  #         expect(current_ownership.registration_info).to eq({ios_version: '1.6.9'})
  #         expect(ActionMailer::Base.deliveries.count).to eq 1
  #         mail = ActionMailer::Base.deliveries.last
  #         expect(mail.subject).to eq("Confirm your #{organization.name} Bike Index registration")
  #         expect(mail.reply_to).to eq(["contact@bikeindex.org"])
  #         expect(mail.from).to eq(["contact@bikeindex.org"])
  #         expect(mail.to).to eq([new_email])
  #       end
  #     end
  #   end

  #   context "updating email address to a new owner with an existing account" do
  #     let!(:new_user) { FactoryBot.create(:user_confirmed, email: "newuser@example.com") }
  #     let(:ownership) { FactoryBot.create(:ownership, owner_email: user.email, user: user, claimed: false) }
  #     before do
  #       bike.reload # Ensure it's established
  #       ActionMailer::Base.deliveries = []
  #       Sidekiq::Job.clear_all
  #       Sidekiq::Testing.inline!
  #     end
  #     after { Sidekiq::Testing.fake! }
  #     it "creates a new ownership, emails owner" do
  #       expect(bike.owner_email).to eq user.email
  #       expect(bike.claimed?).to be_falsey
  #       expect(bike.user).to eq user
  #       expect(bike.authorized?(user)).to be_truthy
  #       expect(bike.owner).not_to eq user
  #       expect {
  #         put url, params: {owner_email: "newuser@EXAMPLE.com "}.to_json, headers: json_headers
  #       }.to change(Ownership, :count).by(1)
  #       expect(response.code).to eq("200")
  #       expect(response.headers["Content-Type"].match("json")).to be_present
  #       bike.reload
  #       ownership.reload
  #       expect(ownership.claimed?).to be_truthy
  #       expect(ownership.current?).to be_falsey
  #       expect(bike.owner_email).to eq new_user.email
  #       expect(bike.user).to eq new_user
  #       expect(bike.claimed?).to be_falsey
  #       expect(bike.current_ownership.id).to_not eq ownership.id
  #       current_ownership = bike.current_ownership
  #       expect(current_ownership.creator_id).to eq user.id
  #       expect(current_ownership.owner_email).to eq new_user.email
  #       expect(ActionMailer::Base.deliveries.count).to eq 1
  #       mail = ActionMailer::Base.deliveries.last
  #       expect(mail.subject).to eq("Confirm your Bike Index registration")
  #       expect(mail.reply_to).to eq(["contact@bikeindex.org"])
  #       expect(mail.from).to eq(["contact@bikeindex.org"])
  #       expect(mail.to).to eq([new_user.email])
  #     end
  #   end
  # end

  # describe "recover" do
  #   let(:url) { "/api/v3/bikes/#{bike.id}/recover?access_token=#{token.token}" }
  #   let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, :with_stolen_record, user: user) }
  #   let!(:stolen_record) { bike.reload.current_stolen_record }
  #   let!(:token) { create_doorkeeper_token(scopes: "read_user read_bikes write_bikes") }
  #   let(:valid_params) do
  #     {
  #       index_helped_recovery: true,
  #       recovered_description: "It was recovered nicely!",
  #       can_share_recovery: false,
  #       recovered_at: Time.current.to_i.to_s
  #     }
  #   end

  #   it "marks unstolen" do
  #     expect(bike.reload.user&.id).to eq user.id
  #     expect(stolen_record).to be_present
  #     expect(bike.status).to eq "status_stolen"
  #     expect(bike.owner_email).to eq user.email
  #     expect(bike.claimed?).to be_truthy
  #     expect(bike.authorized?(user)).to be_truthy
  #     put url, params: valid_params.to_json, headers: json_headers
  #     expect(response.code).to eq("200")
  #     expect(json_result["bike"]["id"]).to eq bike.id
  #     bike.reload
  #     expect(bike.status).to eq "status_with_owner"
  #     expect(stolen_record.reload.current?).to be_falsey
  #     expect(stolen_record.index_helped_recovery?).to be_truthy
  #     expect(stolen_record.recovered_description).to eq valid_params[:recovered_description]
  #     expect(stolen_record.can_share_recovery).to be_falsey
  #   end

  #   context "not stolen" do
  #     let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: user) }
  #     it "errors for a non-stolen bike" do
  #       expect(bike.reload.user&.id).to eq user.id
  #       expect(bike.status).to eq "status_with_owner"
  #       expect(bike.owner_email).to eq user.email
  #       expect(bike.claimed?).to be_truthy
  #       expect(bike.authorized?(user)).to be_truthy
  #       put url, params: valid_params.to_json, headers: json_headers
  #       expect(response.code).to eq("400")
  #       expect(json_result["error"].present?).to be_truthy
  #       expect(json_result["error"]).to match(/stolen/i)
  #     end
  #   end

  #   context "token not write_bikes" do
  #     let!(:token) { create_doorkeeper_token(scopes: "read_user read_bikes") }
  #     it "errors" do
  #       expect(token.reload.scopes.to_s).to_not match(/write_bikes/)
  #       expect(bike.reload.user&.id).to eq user.id
  #       expect(bike.status).to eq "status_stolen"
  #       expect(bike.owner_email).to eq user.email
  #       expect(bike.claimed?).to be_truthy
  #       expect(bike.authorized?(user)).to be_truthy
  #       put url, params: valid_params.to_json, headers: json_headers
  #       expect(response.code).to eq("403")
  #       expect(json_result["error"].present?).to be_truthy
  #       expect(json_result["error"]).to match(/scope/i)
  #     end
  #   end

  #   context "not authorized" do
  #     let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, :with_stolen_record, creator: user) }
  #     it "errors" do
  #       expect(bike.reload.user&.id).to be_present
  #       expect(bike.status).to eq "status_stolen"
  #       expect(bike.claimed?).to be_truthy
  #       expect(bike.authorized?(user)).to be_falsey
  #       put url, params: valid_params.to_json, headers: json_headers
  #       expect(response.code).to eq("403")
  #       expect(json_result["error"].present?).to be_truthy
  #       expect(json_result["error"]).to match(/own/i)
  #     end
  #   end
  # end

  # describe "post id/image" do
  #   let!(:token) { create_doorkeeper_token(scopes: "read_user write_bikes") }
  #   it "doesn't post an image to a bike if the bike isn't owned by the user" do
  #     bike = FactoryBot.create(:ownership).bike
  #     file = File.open(File.join(Rails.root, "spec", "fixtures", "bike.jpg"))
  #     url = "/api/v3/bikes/#{bike.id}/image?access_token=#{token.token}"
  #     expect(bike.public_images.count).to eq(0)
  #     post url, params: {file: Rack::Test::UploadedFile.new(file)}
  #     expect(response.code).to eq("403")
  #     expect(response.headers["Content-Type"].match("json")).to be_present
  #     expect(bike.reload.public_images.count).to eq(0)
  #   end

  #   it "errors on non permitted file extensions" do
  #     bike = FactoryBot.create(:ownership, creator_id: user.id).bike
  #     file = File.open(File.join(Rails.root, "spec", "spec_helper.rb"))
  #     url = "/api/v3/bikes/#{bike.id}/image?access_token=#{token.token}"
  #     expect(bike.public_images.count).to eq(0)
  #     post url, params: {file: Rack::Test::UploadedFile.new(file)}
  #     expect(response.body.match(/not allowed to upload .?.rb/i)).to be_present
  #     expect(response.code).to eq("401")
  #     expect(bike.reload.public_images.count).to eq(0)
  #   end

  #   it "posts an image" do
  #     bike = FactoryBot.create(:ownership, creator_id: user.id).bike
  #     file = File.open(File.join(Rails.root, "spec", "fixtures", "bike.jpg"))
  #     url = "/api/v3/bikes/#{bike.id}/image?access_token=#{token.token}"
  #     expect(bike.public_images.count).to eq(0)
  #     post url, params: {file: Rack::Test::UploadedFile.new(file)}
  #     expect(response.code).to eq("201")
  #     expect(response.headers["Content-Type"].match("json")).to be_present
  #     expect(bike.reload.public_images.count).to eq(1)
  #   end
  # end

  # describe "delete id/image" do
  #   let!(:token) { create_doorkeeper_token(scopes: "read_user write_bikes") }
  #   let(:ownership) { FactoryBot.create(:ownership, creator_id: user.id) }
  #   let(:bike) { ownership.bike }
  #   let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }
  #   it "deletes an image" do
  #     bike.reload
  #     expect(bike.public_images.count).to eq(1)
  #     delete "/api/v3/bikes/#{bike.id}/images/#{public_image.id}?access_token=#{token.token}"
  #     expect(response.code).to eq("200")
  #     expect(json_result["bike"]["public_images"].count).to eq 0
  #     expect(bike.reload.public_images.count).to eq(0)
  #   end
  #   context "not users image" do
  #     let(:public_image) { FactoryBot.create(:public_image) }
  #     it "doesn't delete an image to a bike if the bike isn't owned by the user" do
  #       bike.reload
  #       delete "/api/v3/bikes/#{bike.id}/images/#{public_image.id}?access_token=#{token.token}"
  #       expect(response.code).to eq("404")
  #       public_image.reload
  #       expect(public_image).to be_present
  #     end
  #   end
  # end

  # describe "send_stolen_notification" do
  #   let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership, creator: user) }
  #   let(:params) { {message: "Something I'm sending you"} }
  #   let(:url) { "/api/v3/bikes/#{bike.id}/send_stolen_notification?access_token=#{token.token}" }
  #   let!(:token) { create_doorkeeper_token(scopes: "read_user") }

  #   it "fails to send a stolen notification without read_user" do
  #     token.update_attribute :scopes, "public"
  #     post url, params: params.to_json, headers: json_headers
  #     expect(response.code).to eq("403")
  #     expect(response.body).to match("OAuth")
  #     expect(response.body).to match(/scope/i)
  #     expect(response.body).to_not match("is not stolen")
  #   end

  #   it "fails if the bike isn't stolen" do
  #     bike.current_stolen_record.add_recovery_information
  #     expect(bike.reload.status).to eq "status_with_owner"
  #     post url, params: params.to_json, headers: json_headers
  #     expect(response.code).to eq("400")
  #     expect(response.body.match("Unable to find matching stolen bike")).to be_present
  #   end

  #   it "sends a notification" do
  #     expect(bike.reload.status).to eq "status_stolen"
  #     ActionMailer::Base.deliveries = []
  #     Sidekiq::Job.clear_all

  #     expect do
  #       post url, params: params.to_json, headers: json_headers
  #     end.to change(Email::StolenNotificationJob.jobs, :size).by(1)
  #       .and change(StolenNotification, :count).by 1
  #     expect(response.code).to eq("201")
  #     expect(StolenNotification.last.doorkeeper_app_id).to eq doorkeeper_app.id

  #     Email::StolenNotificationJob.drain
  #     expect(ActionMailer::Base.deliveries).to_not be_empty
  #     mail = ActionMailer::Base.deliveries.last
  #     expect(mail.to).to eq([bike.owner_email])
  #     expect(mail.subject).to eq "Stolen bike contact"
  #     expect(mail.body.encoded).to match params[:message]
  #   end

  #   context "bike isn't owned by current user" do
  #     let!(:bike) { FactoryBot.create(:stolen_bike, :with_ownership) }
  #     it "fails" do
  #       ActionMailer::Base.deliveries = []
  #       Sidekiq::Job.clear_all
  #       expect do
  #         post url, params: params.to_json, headers: json_headers
  #         expect(response.code).to eq("403")
  #         expect(response.body.match("application is not approved")).to be_present
  #       end.to change(Email::StolenNotificationJob.jobs, :size).by(0)
  #         .and change(StolenNotification, :count).by(0)
  #     end

  #     context "Application is approved" do
  #       before { doorkeeper_app.update(can_send_stolen_notifications: true) }

  #       it "sends" do
  #         ActionMailer::Base.deliveries = []
  #         Sidekiq::Job.clear_all
  #         expect do
  #           post url, params: params.to_json, headers: json_headers
  #         end.to change(Email::StolenNotificationJob.jobs, :size).by(1)
  #           .and change(StolenNotification, :count).by(1)
  #         expect(response.code).to eq("201")
  #         stolen_notification = StolenNotification.last
  #         expect(stolen_notification.doorkeeper_app_id).to eq doorkeeper_app.id
  #         expect(stolen_notification.mail_snippet&.id).to be_blank

  #         Email::StolenNotificationJob.drain
  #         expect(ActionMailer::Base.deliveries).to_not be_empty
  #       end

  #       context "mail snippet" do
  #         let(:body) { "Special Stolen Notification Snippet!" }
  #         let!(:mail_snippet) do
  #           FactoryBot.create(:mail_snippet, kind: "stolen_notification_oauth",
  #             doorkeeper_app: doorkeeper_app, body: body)
  #         end
  #         it "includes the mail snippet" do
  #           expect(mail_snippet.reload.is_enabled).to be_truthy
  #           ActionMailer::Base.deliveries = []
  #           Sidekiq::Job.clear_all

  #           expect do
  #             post url, params: params.to_json, headers: json_headers
  #           end.to change(Email::StolenNotificationJob.jobs, :size).by(1)
  #             .and change(StolenNotification, :count).by(1)
  #           expect(response.code).to eq("201")
  #           stolen_notification = StolenNotification.last
  #           expect(stolen_notification.doorkeeper_app_id).to eq doorkeeper_app.id
  #           expect(stolen_notification.mail_snippet&.id).to eq mail_snippet.id

  #           Email::StolenNotificationJob.drain
  #           expect(ActionMailer::Base.deliveries).to_not be_empty
  #           mail = ActionMailer::Base.deliveries.last
  #           expect(mail.to).to eq([bike.owner_email])
  #           expect(mail.subject).to eq "Stolen bike contact"
  #           expect(mail.body.encoded).to match params[:message]
  #           expect(mail.body.encoded).to match body
  #         end
  #       end
  #     end
  #   end
  end
end
