require "rails_helper"

RSpec.describe RegisterController, type: :request do
  let(:base_url) { "/register" }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Trek") }
  let(:color) { FactoryBot.create(:color, name: "Red") }
  let(:owner_email) { "owner@example.com" }
  let(:b_param) do
    BParam.create(origin: "registration_flow",
      params: {bike: {owner_email:, manufacturer_id: "Trek"}}.as_json)
  end

  describe "new" do
    it "renders" do
      get base_url
      expect(response.status).to eq 200
      expect(response).to render_template(:new)
    end
  end

  describe "create" do
    let(:create_params) { {b_param: {manufacturer_id: "Trek", frame_model: "Marlin 7", owner_email:}} }

    it "creates a partial registration, sends the email and redirects to details" do
      expect { post base_url, params: create_params }.to change(BParam, :count).by 1
      new_b_param = BParam.last
      expect(new_b_param).to have_attributes(origin: "registration_flow", owner_email:,
        manufacturer_id: manufacturer.id, creator_id: nil)
      expect(new_b_param.partial_registration?).to be_truthy
      expect(new_b_param.motorized?).to be_falsey
      expect(new_b_param.bike["frame_model"]).to eq "Marlin 7"
      expect(Email::PartialRegistrationJob).to have_enqueued_sidekiq_job(new_b_param.id)
      expect(response).to redirect_to register_details_path(b_param_token: new_b_param.id_token)
    end

    context "motorized, stolen, manufacturer not in the list" do
      let(:create_params) do
        {b_param: {manufacturer_id: "Fancy Cycles", owner_email:},
         propulsion_type_motorized: "1", status: "stolen"}
      end

      it "self-reports the manufacturer and keeps motorized and status" do
        expect { post base_url, params: create_params }.to change(BParam, :count).by 1
        new_b_param = BParam.last
        expect(new_b_param).to have_attributes(owner_email:, manufacturer_id: Manufacturer.other.id,
          status: "status_stolen")
        expect(new_b_param.bike["manufacturer_other"]).to eq "Fancy Cycles"
        expect(new_b_param.motorized?).to be_truthy
      end
    end

    context "blank email" do
      let(:create_params) { {b_param: {manufacturer_id: "Trek", owner_email: " "}} }

      it "renders new with an error" do
        expect { post base_url, params: create_params }.to_not change(BParam, :count)
        expect(response.status).to eq 422
        expect(response).to render_template(:new)
      end
    end
  end

  describe "details" do
    it "renders, showing the email from step 1" do
      get register_details_path(b_param_token: b_param.id_token)
      expect(response.status).to eq 200
      expect(response).to render_template(:details)
      expect(response.body).to include owner_email
    end

    context "unknown token" do
      it "redirects to the start" do
        get register_details_path(b_param_token: "unknown-token")
        expect(response).to redirect_to register_path
        expect(flash[:info]).to be_present
      end
    end
  end

  describe "update" do
    let(:bike_details) do
      {primary_frame_color_id: color.id, serial_number: "XYZ 123", frame_size: "m",
       phone: "(555) 000-0000", status: "status_with_owner"}
    end

    context "anonymous" do
      it "saves the details on the b_param without creating a bike" do
        expect {
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
        }.to_not change(Bike, :count)
        expect(response).to redirect_to register_complete_path(b_param_token: b_param.id_token)
        b_param.reload
        # IDs pass through as posted strings; they're cast when the bike is created
        expect(b_param.bike).to match_hash_indifferently(bike_details.merge(owner_email:,
          manufacturer_id: manufacturer.id, primary_frame_color_id: color.id.to_s))
        follow_redirect!
        expect(response.body).to include "Check your email"
      end

      context "motorized" do
        let(:b_param) do
          BParam.create(origin: "registration_flow",
            params: {bike: {owner_email:, manufacturer_id: "Trek"}, propulsion_type_motorized: "1"}.as_json)
        end

        it "completes directly, keeping motorized" do
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          expect(response).to redirect_to register_complete_path(b_param_token: b_param.id_token)
          expect(b_param.reload.motorized?).to be_truthy
        end
      end
    end

    context "signed in" do
      include_context :request_spec_logged_in_as_user

      it "creates the bike and completes registration" do
        expect {
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
        }.to change(Bike, :count).by 1
        bike = Bike.last
        expect(bike).to have_attributes(manufacturer_id: manufacturer.id,
          primary_frame_color_id: color.id, serial_number: "XYZ 123",
          owner_email:, creator_id: current_user.id)
        expect(bike.current_ownership.origin).to eq "registration_flow"
        expect(b_param.reload.created_bike_id).to eq bike.id
        expect(response).to redirect_to register_complete_path(b_param_token: b_param.id_token)
        follow_redirect!
        expect(response.body).to include "Registration complete"

        # Revisiting a step after completion goes back to complete
        get register_details_path(b_param_token: b_param.id_token)
        expect(response).to redirect_to register_complete_path(b_param_token: b_param.id_token)
      end

      context "blank serial" do
        let(:bike_details) { {primary_frame_color_id: color.id, status: "status_with_owner"} }

        it "registers with an unknown serial" do
          expect {
            patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          }.to change(Bike, :count).by 1
          expect(Bike.last.serial_number).to eq "unknown"
        end
      end

      context "b_param created by a different user" do
        let(:b_param) do
          BParam.create(origin: "registration_flow", creator_id: FactoryBot.create(:user_confirmed).id,
            params: {bike: {owner_email:}}.as_json)
        end

        it "does not find the registration" do
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          expect(response).to redirect_to register_path
          expect(flash[:info]).to be_present
        end
      end
    end
  end
end
