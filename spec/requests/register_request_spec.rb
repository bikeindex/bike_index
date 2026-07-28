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
    it "creates an empty registration and redirects to its step 1" do
      expect { get "/register/new" }.to change(BParam, :count).by 1
      new_b_param = BParam.last
      expect(new_b_param.origin).to eq "registration_flow"
      expect(new_b_param.confirmation_token).to be_present
      expect(response).to redirect_to register_path(b_param_token: new_b_param.id_token, step: 1)

      # Revisiting reuses the session's still-blank registration
      expect { get "/register/new" }.to_not change(BParam, :count)
      expect(response).to redirect_to register_path(b_param_token: new_b_param.id_token, step: 1)

      # Once step 1 is submitted, register/new starts a fresh registration
      new_b_param.clean_params({bike: {owner_email:}}.as_json)
      new_b_param.save
      expect { get "/register/new" }.to change(BParam, :count).by 1
      expect(response).to_not redirect_to register_path(b_param_token: new_b_param.id_token, step: 1)
    end

    context "stolen status param" do
      it "stores the status" do
        get "/register/new?status=stolen"
        expect(BParam.last.status).to eq "status_stolen"
      end
    end

    it "creates a registration that CleanBParamsJob deletes once stale, if never submitted" do
      get "/register/new?status=stolen" # status alone doesn't count as a submitted value
      new_b_param = BParam.last
      expect(CleanBParamsJob.new.b_params.pluck(:id)).to eq []
      new_b_param.update_column(:updated_at, CleanBParamsJob.clean_before - 1.hour)
      expect(CleanBParamsJob.new.b_params.pluck(:id)).to eq([new_b_param.id])
      expect { CleanBParamsJob.new.perform }.to change(BParam, :count).by(-1)

      # Submitting step 1 makes it worth keeping
      get "/register/new"
      submitted_b_param = BParam.last
      post base_url, params: {b_param_token: submitted_b_param.id_token,
                              b_param: {manufacturer_id: "Trek", cycle_type: "bike", owner_email:}}
      submitted_b_param.update_column(:updated_at, CleanBParamsJob.clean_before - 1.hour)
      expect { CleanBParamsJob.new.perform }.to_not change(BParam, :count)
    end

    it "redirects the bare /register" do
      get base_url
      expect(response).to redirect_to new_register_path
      expect(flash[:info]).to be_nil
    end
  end

  describe "show step: 1" do
    it "renders" do
      get register_path(b_param_token: b_param.id_token, step: 1)
      expect(response.status).to eq 200
      expect(response.body).to include "Register your bike!"
      # Controller-rendered components still wrap in the application layout
      expect(response.body).to include "</html>"
      # Prefilled from the registration, so going back to step 1 keeps the values
      expect(response.body).to include owner_email
    end

    context "unknown token" do
      it "redirects to the start" do
        get register_path(b_param_token: "unknown-token", step: 1)
        expect(response).to redirect_to new_register_path
        expect(flash[:info]).to be_present
      end
    end
  end

  describe "create" do
    let!(:empty_b_param) { BParam.create(origin: "registration_flow") }
    let(:step_1_params) { {b_param: {manufacturer_id: "Trek", cycle_type: "cargo", owner_email:}} }
    let(:create_params) { step_1_params.merge(b_param_token: empty_b_param.id_token) }

    it "saves step 1, sends the email and redirects to step 2" do
      expect { post base_url, params: create_params }.to_not change(BParam, :count)
      empty_b_param.reload
      expect(empty_b_param).to have_attributes(origin: "registration_flow", owner_email:,
        manufacturer_id: manufacturer.id, creator_id: nil, cycle_type: "cargo")
      expect(empty_b_param.partial_registration?).to be_truthy
      expect(empty_b_param.motorized?).to be_falsey
      expect(Email::PartialRegistrationJob).to have_enqueued_sidekiq_job(empty_b_param.id)
      expect(response).to redirect_to register_path(b_param_token: empty_b_param.id_token, step: 2)

      # Resubmitting with the same email doesn't resend the confirmation
      expect {
        post base_url, params: create_params
      }.to_not change { Email::PartialRegistrationJob.jobs.size }

      # Changing the email does - the old link only proved control of the old address
      expect {
        post base_url, params: create_params.deep_merge(b_param: {owner_email: "new@example.com"})
      }.to change { Email::PartialRegistrationJob.jobs.size }.by 1
    end

    context "motorized, stolen, manufacturer not in the list" do
      let(:step_1_params) do
        {b_param: {manufacturer_id: "Fancy Cycles", owner_email:},
         propulsion_type_motorized: "1", status: "stolen"}
      end

      it "self-reports the manufacturer and keeps motorized and status" do
        post base_url, params: create_params
        empty_b_param.reload
        expect(empty_b_param).to have_attributes(owner_email:, manufacturer_id: Manufacturer.other.id,
          status: "status_stolen")
        expect(empty_b_param.bike["manufacturer_other"]).to eq "Fancy Cycles"
        expect(empty_b_param.motorized?).to be_truthy
      end
    end

    context "always-motorized cycle type" do
      let(:step_1_params) { {b_param: {manufacturer_id: "Trek", cycle_type: "e-scooter", owner_email:}} }

      it "is motorized without the checkbox" do
        post base_url, params: create_params
        expect(empty_b_param.reload.motorized?).to be_truthy
      end
    end

    context "blank email" do
      let(:step_1_params) { {b_param: {manufacturer_id: "Trek", owner_email: " "}} }

      it "renders step 1 with an error, saving nothing" do
        post base_url, params: create_params
        expect(response.status).to eq 422
        expect(response.body).to include "Email is required to register"
        expect(empty_b_param.reload.manufacturer_id).to be_nil
      end
    end

    context "blank manufacturer" do
      let(:step_1_params) { {b_param: {manufacturer_id: "", owner_email:}} }

      it "renders step 1 with an error" do
        post base_url, params: create_params
        expect(response.status).to eq 422
        expect(response.body).to include "Manufacturer is required"
      end
    end

    context "unknown token" do
      it "redirects to the start" do
        post base_url, params: step_1_params.merge(b_param_token: "unknown-token")
        expect(response).to redirect_to new_register_path
      end
    end
  end

  describe "show step: 2" do
    it "renders the details form, showing the email from step 1" do
      get register_path(b_param_token: b_param.id_token, step: 2)
      expect(response.status).to eq 200
      expect(response.body).to include "Add your bike"
      expect(response.body).to include owner_email
    end

    context "step 1 not submitted" do
      let(:b_param) { BParam.create(origin: "registration_flow") }

      it "redirects to step 1" do
        get register_path(b_param_token: b_param.id_token, step: 2)
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: 1)
      end
    end
  end

  describe "show" do
    it "redirects an in-progress registration to its step" do
      get register_path(b_param_token: b_param.id_token)
      expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: 2)
    end

    context "unknown token" do
      it "redirects to the start" do
        get register_path(b_param_token: "unknown-token")
        expect(response).to redirect_to new_register_path
        expect(flash[:info]).to be_present
      end
    end
  end

  describe "update" do
    let(:bike_details) do
      {primary_frame_color_id: color.id, serial_number: "XYZ 123", frame_size: "m",
       frame_model: "Marlin 7", year: "2023", phone: "(555) 000-0000", status: "status_with_owner"}
    end

    context "anonymous" do
      it "saves the details on the b_param without creating a bike" do
        expect {
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
        }.to_not change(Bike, :count)
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :complete)
        b_param.reload
        expect(b_param.details_completed?).to be_truthy
        # IDs pass through as posted strings; they're cast when the bike is created
        expect(b_param.bike).to match_hash_indifferently(bike_details.merge(owner_email:,
          manufacturer_id: manufacturer.id, primary_frame_color_id: color.id.to_s))
        follow_redirect!
        expect(response.body).to include "Registration complete"
        expect(response.body).to include "verify your email"
      end

      context "missing serial" do
        it "stores unknown and made_without_serial serials" do
          patch base_url, params: {b_param_token: b_param.id_token,
                                   bike: {serial_number: "unknown", status: "status_with_owner"}}
          expect(b_param.reload.bike["serial_number"]).to eq "unknown"

          patch base_url, params: {b_param_token: b_param.id_token,
                                   bike: {serial_number: "made_without_serial", status: "status_with_owner"}}
          expect(b_param.reload.bike["serial_number"]).to eq "made_without_serial"
        end
      end

      context "with a photo" do
        it "attaches the image to the b_param" do
          patch base_url, params: {b_param_token: b_param.id_token,
                                   bike: bike_details.merge(image: Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/bike.jpg"), "image/jpeg"))}
          expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :complete)
          expect(b_param.reload.image).to be_present
          # The uploaded file doesn't leak into the JSON params
          expect(b_param.params.to_json).to_not include "bike.jpg"
        end
      end

      context "frame size in cm" do
        it "saves the unit with the number, dropping it otherwise" do
          patch base_url, params: {b_param_token: b_param.id_token,
                                   bike: {frame_size_number: "56", frame_size_unit: "cm", status: "status_with_owner"}}
          expect(b_param.reload.bike).to match_hash_indifferently(
            owner_email:, manufacturer_id: manufacturer.id,
            frame_size_number: "56", frame_size_unit: "cm", status: "status_with_owner"
          )

          patch base_url, params: {b_param_token: b_param.id_token,
                                   bike: {frame_size: "m", frame_size_unit: "in", status: "status_with_owner"}}
          expect(b_param.reload.bike["frame_size"]).to eq "m"
          expect(b_param.bike["frame_size_unit"]).to eq "cm" # unit without a number isn't overwritten
        end
      end

      context "additional colors" do
        let(:color2) { FactoryBot.create(:color, name: "Blue") }

        it "saves them and clears them when posted blank (remove additional color)" do
          patch base_url, params: {b_param_token: b_param.id_token,
                                   bike: bike_details.merge(secondary_frame_color_id: color2.id)}
          expect(b_param.reload.bike["secondary_frame_color_id"]).to eq color2.id.to_s

          patch base_url, params: {b_param_token: b_param.id_token,
                                   bike: bike_details.merge(secondary_frame_color_id: "")}
          expect(b_param.reload.bike["secondary_frame_color_id"]).to be_blank
        end
      end

      context "email already confirmed" do
        let!(:user) { FactoryBot.create(:user_confirmed, email: owner_email) }

        it "creates the bike with the email's user as creator" do
          b_param.confirm_email!
          expect {
            patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          }.to change(Bike, :count).by 1
          expect(Bike.last).to have_attributes(owner_email:, creator_id: user.id)
          expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :complete)
        end
      end

      context "motorized" do
        let(:b_param) do
          BParam.create(origin: "registration_flow",
            params: {bike: {owner_email:, manufacturer_id: "Trek"}, propulsion_type_motorized: "1"}.as_json)
        end

        it "completes directly, keeping motorized" do
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :complete)
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
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :complete)
        follow_redirect!
        expect(response.body).to include "Registration complete"

        # Revisiting any step after completion redirects to complete
        get register_path(b_param_token: b_param.id_token, step: 2)
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :complete)
        get register_path(b_param_token: b_param.id_token, step: 1)
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :complete)
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
          expect(response).to redirect_to new_register_path
          expect(flash[:info]).to be_present
        end
      end
    end
  end

  describe "confirm" do
    let(:bike_details) do
      {primary_frame_color_id: color.id, serial_number: "XYZ 123", status: "status_with_owner"}
    end
    let(:confirm_path) do
      register_path(b_param_token: b_param.id_token,
        confirmation_token: b_param.confirmation_token)
    end

    context "details completed, a user exists for the email" do
      let!(:user) { FactoryBot.create(:user_confirmed, email: owner_email) }

      it "creates the bike with that user as creator" do
        patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
        expect {
          get confirm_path
        }.to change(Bike, :count).by 1
        bike = Bike.last
        expect(bike).to have_attributes(owner_email:, creator_id: user.id,
          manufacturer_id: manufacturer.id)
        expect(b_param.reload.email_confirmed?).to be_truthy
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :complete)
        follow_redirect!
        expect(response.body).to include "Registration complete"

        # Clicking the link again just redirects to complete
        expect { get confirm_path }.to_not change(Bike, :count)
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :complete)
      end
    end

    context "details completed, no user for the email" do
      let!(:auto_org_user) { FactoryBot.create(:user_confirmed, email: "auto_user@bikeindex.org") }

      it "creates the bike with the AUTO_ORG_MEMBER user as creator" do
        stub_const("ENV", ENV.to_hash.merge("AUTO_ORG_MEMBER" => auto_org_user.email))
        patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
        expect { get confirm_path }.to change(Bike, :count).by 1
        expect(Bike.last).to have_attributes(owner_email:, creator_id: auto_org_user.id)
      end
    end

    context "details not completed" do
      it "confirms the email and sends them to step 2" do
        expect { get confirm_path }.to_not change(Bike, :count)
        expect(b_param.reload.email_confirmed?).to be_truthy
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: 2)
        expect(flash[:success]).to be_present
      end
    end

    context "invalid confirmation token" do
      it "redirects to the start without confirming" do
        get register_path(b_param_token: b_param.id_token, confirmation_token: "wrong")
        expect(response).to redirect_to new_register_path
        expect(flash[:error]).to be_present
        expect(b_param.reload.email_confirmed?).to be_falsey
      end
    end
  end
end
