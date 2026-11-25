require "rails_helper"

RSpec.describe "Me API V3", type: :request do
  include_context :existing_doorkeeper_app
  describe "unauthorized current" do
    it "Sends correct error code when no user present" do
      get "/api/v3/me"
      expect(response.response_code).to eq(401)
      expect(response.body.match("OAuth")).to be_present
      expect(response.headers["Content-Type"].match("json")).to be_present
      expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
      expect(response.headers["Access-Control-Request-Method"]).to eq("*")
    end
  end

  describe "authorized current" do
    let!(:token) { create_doorkeeper_token(scopes: scopes) }
    let(:scopes) { "public read_user read_bikes" }

    context "fully scoped token" do
      let(:scopes) { all_scopes }
      let!(:secondary_email) { FactoryBot.create(:user_email, user: user, email: "d@f.co") }
      let(:role) { "member" }
      let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user:, role:) }
      let(:organization) { organization_role.organization }
      # The grouped menu the sidebar renders, which is what this serves now
      let(:target_menu) do
        [
          {type: "group", key: "registrations", label: "#{organization.short_name} Registrations",
           icon: "bike",
           children: [
             {type: "link", label: "Search Registrations",
              path: "/o/#{organization.slug}/registrations", icon: nil},
             {type: "link", label: "Multi search",
              path: "/o/#{organization.slug}/registrations/multi_search", icon: nil}
           ]},
          {type: "link", label: "Add a registration", path: "/o/#{organization.slug}/registrations/new",
           icon: "plus-circle", match_params: {parking_notification: nil}},
          {type: "divider"},
          {type: "link", label: "#{organization.short_name} Information",
           path: "/o/#{organization.slug}/info", icon: nil}
        ]
      end
      let(:target_membership) do
        {
          organization_name: organization.name,
          organization_short_name: organization.short_name,
          organization_slug: organization.slug,
          organization_id: organization.id,
          organization_access_token: organization.access_token,
          organization_logo_url: nil,
          user_is_organization_admin: false,
          menu: target_menu
        }
      end
      it "responds with all available attributes with full scoped token" do
        user.reload
        expect(user.secondary_emails).to eq(["d@f.co"])
        expect(organization_role.organization.avatar?).to be_falsey
        get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
        expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
        expect(json_result["user"]["name"]).to eq(user.name)
        expect(json_result["user"]["secondary_emails"]).to eq(["d@f.co"])
        expect(json_result["id"]).to eq(user.id.to_s)
        expect(json_result["user"].is_a?(Hash)).to be_truthy
        expect(json_result["bike_ids"].is_a?(Array)).to be_truthy
        expect(json_result["memberships"].is_a?(Array)).to be_truthy
        expect(json_result["memberships"]).to eq([target_membership.as_json])
        expect(response.response_code).to eq(200)
      end

      context "member_no_bike_edit" do
        let(:role) { "member_no_bike_edit" }
        it "doesn't include the organization access_token" do
          get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
          expect(response.response_code).to eq(200)
          membership = json_result["memberships"].first
          expect(membership["user_is_organization_admin"]).to be_falsey
          expect(membership["organization_access_token"]).to be_nil
        end
      end

      context "organization with uploaded avatar" do
        let(:avatar) { Rack::Test::UploadedFile.new(File.open(Rails.root.join("spec/fixtures/bike.jpg"))) }
        before { organization_role.organization.update!(avatar: avatar) }
        it "returns the avatar URL as organization_logo_url" do
          get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
          expect(response.response_code).to eq(200)
          expect(organization_role.organization.reload).to have_attributes(avatar?: true)
          expect(json_result["memberships"]).to eq([target_membership.merge(organization_logo_url: organization_role.organization.avatar_url).as_json])
        end
      end
    end

    context "unconfirmed user" do
      let(:time) { Time.current - 1.month }
      let(:user) { FactoryBot.create(:user, created_at: time) }
      it "responds with unauthorized" do
        user.reload
        expect(user.confirmed?).to be_falsey
        get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
        expect(response.response_code).to eq(403)
        expect(json_result[:error]).to be_present
      end

      context "app with unconfirmed scope" do
        let(:scopes) { "public read_user unconfirmed" }
        it "responds with all available attributes" do
          get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
          expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
          expect(json_result[:user][:name]).to eq(user.name)
          expect(json_result[:user][:secondary_emails]).to eq([])
          expect(json_result[:user][:confirmed]).to be_falsey
          expect(json_result[:id]).to eq(user.id.to_s)
          expect(Time.at(json_result[:user][:created_at])).to be_within(1.second).of time
          expect(json_result[:user].is_a?(Hash)).to be_truthy
          expect(json_result.key?("bike_ids")).to be_falsey
          expect(json_result.key?("memberships")).to be_falsey
          expect(response.response_code).to eq(200)
        end
        context "user not present" do
          it "responds with 401" do
            get "/api/v3/me", params: {access_token: "FAKETOKEN"}, headers: {format: :json}
            expect(response.response_code).to eq(401)
            expect(response.body.match("OAuth")).to be_present
          end
        end
      end
    end

    context "no bikes scoped" do
      let(:scopes) { "public" }
      it "doesn't include bikes" do
        expect(token.scopes.to_s.match("read_bikes").present?).to be_falsey
        get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
        expect(response.response_code).to eq(200)
        expect(json_result["id"]).to eq(user.id.to_s)
        expect(json_result["bike_ids"].present?).to be_falsey
        expect(json_result["user"]).to be_nil
      end
    end

    context "no membership scoped" do
      it "doesn't include memberships if no memberships scoped" do
        expect(token.scopes.to_s.match("read_organization_membership").present?).to be_falsey
        get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
        expect(response.response_code).to eq(200)
        result = JSON.parse(response.body)
        expect(result["id"]).to eq(user.id.to_s)
        expect(result["memberships"].present?).to be_falsey
      end
    end

    context "Default scope" do
      let(:scopes) { "" }
      it "doesn't include memberships" do
        get "/api/v3/me", params: {access_token: token.token}, headers: {format: :json}
        expect(response.response_code).to eq(200)
        result = JSON.parse(response.body)
        expect(result["id"]).to eq(user.id.to_s)
        expect(result["user"].present?).to be_falsey
      end
    end
  end

  describe "current/bikes" do
    before { expect(doorkeeper_app).to be_present }

    it "works if it's authorized" do
      token.update_attribute :scopes, "read_bikes"
      get "/api/v3/me/bikes", params: {access_token: token.token}, headers: {format: :json}
      # get "/api/v3/me/bikes", {}, "Authorization" => "Basic #{Base64.encode64("#{token.token}:X")}"
      expect(json_result["bikes"].is_a?(Array)).to be_truthy
      expect(response.response_code).to eq(200)
    end

    context "with for sale bike" do
      let!(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: user.email, is_for_sale: true) }

      it "uses BikeV3Serializer (status not 'for sale', for_sale: true)" do
        token.update_attribute :scopes, "read_bikes"
        get "/api/v3/me/bikes", params: {access_token: token.token}, headers: {format: :json}
        expect(response.response_code).to eq(200)
        result = json_result["bikes"].find { |b| b["id"] == bike.id }
        expect(result).to include("status" => "with owner", "for_sale" => true)
      end
    end

    context "with impounded bike" do
      let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user:) }
      before { FactoryBot.create(:impound_record, bike:) }

      it "shows the owner the serial" do
        token.update_attribute :scopes, "read_bikes"
        get "/api/v3/me/bikes", params: {access_token: token.token}, headers: {format: :json}
        result = json_result["bikes"].find { |b| b["id"] == bike.id }
        expect(result).to include("status" => "found", "serial" => bike.serial_number.upcase)
      end
    end

    it "403s if read_bikes_spec isn't in token" do
      get "/api/v3/me/bikes", params: {access_token: token.token}, headers: {format: :json}
      expect(response.response_code).to eq(403)
    end
  end

  describe "current/alerts" do
    it "403s if read_user isn't in token" do
      get "/api/v3/me/alerts", params: {access_token: token.token}
      expect(response.response_code).to eq(403)
    end

    context "with alerts" do
      let(:token) { create_doorkeeper_token(scopes: "read_user") }
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user:) }
      let(:organization) { FactoryBot.create(:organization) }
      let!(:user_alert_photo) do
        FactoryBot.create(:user_alert, user:, bike:, kind: "theft_alert_without_photo")
      end
      let!(:user_alert_org) do
        FactoryBot.create(:user_alert, user:, bike:, organization:, kind: "unassigned_bike_org")
      end
      let!(:user_alert_location) { FactoryBot.create(:user_alert_stolen_bike_without_location, user:) }
      let!(:b_param) { FactoryBot.create(:b_param_unfinished_registration, creator: user) }
      let(:user_phone) { FactoryBot.create(:user_phone, user:, phone: "4334444444") }
      let(:target_alerts) do
        [
          {id: user_alert_photo.id, kind: "theft_alert_without_photo", title: "Please add a photo",
           message: "Successful promoted alerts need to have an image",
           action: "Add a photo to your #{bike.title_string}", url: "#{ENV["BASE_URL"]}/bikes/#{bike.to_param}/edit/photos", bike_id: bike.id,
           organization_id: nil, created_at: user_alert_photo.created_at.to_i},
          {id: user_alert_org.id, kind: "unassigned_bike_org", title: nil,
           message: "Some of your registrations are connected to #{organization.short_name}, but your " \
             "#{bike.title_string} isn't. Generally, you should connect all of them to #{organization.short_name}.",
           action: "Add it now!", url: "#{ENV["BASE_URL"]}/my_account", bike_id: bike.id,
           organization_id: organization.id, created_at: user_alert_org.created_at.to_i},
          {id: user_alert_location.id, kind: "stolen_bike_without_location", title: "Please add theft location",
           message: "It is critical for recovery that you include the address or cross-street where your bike was stolen.",
           action: "Add the location of the theft of your #{user_alert_location.bike.title_string}", url: "#{ENV["BASE_URL"]}/bikes/#{user_alert_location.bike.to_param}/edit/theft_details#where-theft-happened",
           bike_id: user_alert_location.bike_id, organization_id: nil, created_at: user_alert_location.created_at.to_i}
        ]
      end

      it "responds with the active alerts, in plain text" do
        UserAlert.update_unfinished_registrations(user)
        UserAlert.update_phone_waiting_confirmation(user:, user_phone:)
        FactoryBot.create(:user_alert, user:, bike:, kind: "theft_alert_without_photo", resolved_at: Time.current)
        FactoryBot.create(:user_alert, kind: "theft_alert_without_photo")

        get "/api/v3/me/alerts", params: {access_token: token.token}
        expect(response.response_code).to eq(200)
        expect(response.headers["Access-Control-Allow-Origin"]).to eq("*")
        user_alert_registration = user.user_alerts.unfinished_registration.first
        target_registration = {id: user_alert_registration.id, kind: "unfinished_registration",
                               title: nil, message: "Your Surly cargo bike isn't registered yet! Please finish the required steps",
                               action: "finish the required steps",
                               url: "#{ENV["BASE_URL"]}/register?b_param_token=#{b_param.id_token}",
                               bike_id: nil, organization_id: nil, created_at: user_alert_registration.created_at.to_i}
        # phone_waiting_confirmation is behind a flag
        expect(json_result[:alerts]).to match_array((target_alerts + [target_registration]).as_json)

        Flipper.enable(:phone_verification)
        # Expiry is silent, so the alert stays active
        b_param.update_column(:created_at, Time.current - BParam::TOKEN_EXPIRATION - 1.day)
        expect(user.user_alerts.active.unfinished_registration.count).to eq 1

        get "/api/v3/me/alerts", params: {access_token: token.token}
        user_alert_phone = user.user_alerts.phone_waiting_confirmation.first
        target_phone = {id: user_alert_phone.id, kind: "phone_waiting_confirmation",
                        title: "Verify 433-444-4444", message: nil, action: "Confirm your phone number",
                        url: "#{ENV["BASE_URL"]}/my_account/edit", bike_id: nil, organization_id: nil,
                        created_at: user_alert_phone.created_at.to_i}
        expect(json_result[:alerts]).to match_array((target_alerts + [target_phone]).as_json)
      end
    end
  end
end
