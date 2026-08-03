require "rails_helper"

RSpec.describe RegisterController, type: :request do
  let(:base_url) { "/register" }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Trek") }
  let(:color) { FactoryBot.create(:color, name: "Red") }
  let(:owner_email) { "owner@example.com" }
  let(:user_name) { "Sally Rider" }
  let(:b_param) do
    BParam.create(origin: "register_flow",
      params: {bike: {owner_email:, manufacturer_id: "Trek"}}.as_json)
  end

  describe "new" do
    it "creates an empty registration and redirects to its step 1" do
      expect { get "/register/new" }.to change(BParam, :count).by 1
      new_b_param = BParam.last
      expect(new_b_param.origin).to eq "register_flow"
      expect(response).to redirect_to register_path(b_param_token: new_b_param.id_token, step: 1)

      # Revisiting reuses the session's still-blank registration
      expect { get "/register/new" }.to_not change(BParam, :count)
      expect(response).to redirect_to register_path(b_param_token: new_b_param.id_token, step: 1)

      # Once step 1 is submitted (manufacturer is the marker), register/new starts fresh
      new_b_param.clean_params({bike: {manufacturer_id: manufacturer.id, owner_email:}}.as_json)
      new_b_param.save
      expect { get "/register/new" }.to change(BParam, :count).by 1
      expect(response).to_not redirect_to register_path(b_param_token: new_b_param.id_token, step: 1)
    end

    context "status and organization params" do
      let(:organization) { FactoryBot.create(:organization) }

      it "stores them on the registration it creates, keeping them on revisit" do
        # The slug resolves to the organization, rather than being stored as-is
        get "/register/new?status=status_stolen&organization_id=#{organization.slug}"
        stolen_b_param = BParam.last
        expect(stolen_b_param).to have_attributes(status: "status_stolen",
          creation_organization_id: organization.id, organization_id: organization.id)

        get "/register/new?status=status_impounded"
        expect(BParam.last.id).to eq stolen_b_param.id
        expect(stolen_b_param.reload.status).to eq "status_stolen"
      end

      # The organization's link is /register, which has no registration to attach to yet
      it "keeps the organization through the bare /register" do
        get "#{base_url}?organization_id=#{organization.slug}"
        follow_redirect! # into /register/new, which creates the registration
        expect(BParam.last.creation_organization_id).to eq organization.id
      end

      # Only the create branch of b_param_for seeds status, so this is the org path
      it "attaches the organization to a blank registration already in the session" do
        get "/register/new" # a blank shell, no organization
        session_b_param = BParam.last
        expect(session_b_param.creation_organization_id).to be_blank

        # Arriving on the organization's link shouldn't quietly go unattributed
        expect { get "/register/new?organization_id=#{organization.slug}" }.to_not change(BParam, :count)
        expect(session_b_param.reload.creation_organization_id).to eq organization.id
      end
    end

    it "creates a registration that CleanBParamsJob deletes once stale, if never submitted" do
      get "/register/new?status=status_stolen" # status alone doesn't count as a submitted value
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

    context "signed in" do
      include_context :request_spec_logged_in_as_user

      it "prefills owner_email with the user's email, still landing on step 1" do
        get "/register/new"
        new_b_param = BParam.last
        expect(new_b_param.owner_email).to eq current_user.email
        expect(response).to redirect_to register_path(b_param_token: new_b_param.id_token, step: 1)
      end
    end

    context "email param" do
      it "uses the passed address, and blanks it for false" do
        get "/register/new?email=someone@example.com"
        passed = BParam.last
        expect(passed.owner_email).to eq "someone@example.com"

        # A blank param leaves the reused registration's address alone
        get "/register/new"
        expect(passed.reload.owner_email).to eq "someone@example.com"

        # false blanks it, even though it's already set
        get "/register/new?email=false"
        expect(passed.reload.owner_email).to be_nil
      end

      context "signed in" do
        include_context :request_spec_logged_in_as_user

        it "prefers the passed address over the user's, and false over both" do
          get "/register/new?email=false"
          expect(BParam.last.owner_email).to be_nil

          get "/register/new?email=someone@example.com"
          expect(BParam.last.owner_email).to eq "someone@example.com"

          get "/register/new?b_param_token=false"
          expect(BParam.last.owner_email).to eq current_user.email
        end
      end
    end

    it "starts a fresh registration with b_param_token=false, ignoring the session's" do
      get "/register/new"
      session_b_param = BParam.last
      expect { get "/register/new?b_param_token=false" }.to change(BParam, :count).by 1
      expect(BParam.last.id).to_not eq session_b_param.id
      expect(response).to redirect_to register_path(b_param_token: BParam.last.id_token, step: 1)

      # The new registration is now the session's, so /register/new reuses it again
      expect { get "/register/new" }.to_not change(BParam, :count)
    end

    it "redirects the bare /register" do
      get base_url
      expect(response).to redirect_to new_register_path
      expect(flash[:notice]).to be_nil

      # How they arrived rides along - there's no registration yet to store it on
      get "#{base_url}?organization_id=brakebills&status=status_stolen&email=someone@example.com"
      expect(response).to redirect_to new_register_path(organization_id: "brakebills",
        status: "status_stolen", email: "someone@example.com")

      # With a session registration, bare /register resumes it instead
      get "/register/new"
      session_b_param = BParam.last
      get base_url
      expect(response).to redirect_to register_path(b_param_token: session_b_param.id_token, step: 1)
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
      # Never cached - the step shown depends on server state
      expect(response.headers["Cache-Control"]).to eq "no-store"
      expect(response.body).to include "email a confirmation link"
      # Submitted already, so this is a return from step 2 - offer abandoning it
      expect(response.body).to include "Start over"
    end

    context "signed in" do
      include_context :request_spec_logged_in_as_user

      it "notes the confirmation link - the address is someone else's" do
        get register_path(b_param_token: b_param.id_token, step: 1)
        expect(response.status).to eq 200
        expect(response.body).to include "email a confirmation link"
      end

      context "registering to their own address" do
        let(:owner_email) { current_user.email }

        it "skips the note - signing in already proved the address" do
          get register_path(b_param_token: b_param.id_token, step: 1)
          expect(response.body).to_not include "email a confirmation link"
        end
      end
    end

    context "with an organization" do
      let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
      let(:b_param) do
        BParam.create(origin: "register_flow",
          params: {bike: {owner_email:, cycle_type: "cargo", creation_organization_id: organization.id}}.as_json)
      end

      it "names the organization in the heading, with the cycle type js can swap" do
        get register_path(b_param_token: b_param.id_token, step: 1)
        expect(response.body).to include "Register your <span data-register--heading-target=\"cycleType\">cargo bike</span> with Brakebills!"
        # Posted back, so a submission that has to build a registration keeps the org
        expect(Nokogiri::HTML(response.body).at_css("input[name='organization_id']")["value"])
          .to eq organization.id.to_s
      end

      context "started as stolen" do
        let(:b_param) do
          BParam.create(origin: "register_flow", params: {bike: {owner_email:, manufacturer_id: "Trek",
                                                                 creation_organization_id: organization.id, status: "status_stolen"}}.as_json)
        end

        it "carries the organization and status onto the start over link" do
          get register_path(b_param_token: b_param.id_token, step: 1)
          start_over = Nokogiri::HTML(response.body).at_css("#start-over-modal a")["href"]
          expect(start_over).to eq new_register_path(b_param_token: false,
            organization_id: organization.slug, status: "status_stolen")
        end
      end

      context "organization_id in the url" do
        let(:b_param) do
          BParam.create(origin: "register_flow", params: {bike: {owner_email:, manufacturer_id: "Trek"}}.as_json)
        end

        it "adds the organization to a registration already underway, by slug" do
          get register_path(b_param_token: b_param.id_token, step: 1, organization_id: organization.slug)
          expect(b_param.reload.creation_organization_id).to eq organization.id
          expect(b_param.organization_id).to eq organization.id
          expect(response.body).to include "with Brakebills!"

          # Once the bike exists there's nothing left to attribute
          b_param.update(created_bike_id: FactoryBot.create(:bike).id)
          get register_path(b_param_token: b_param.id_token, organization_id: FactoryBot.create(:organization).slug)
          expect(b_param.reload.creation_organization_id).to eq organization.id
        end
      end
    end

    context "step 1 not submitted" do
      let(:b_param) { BParam.create(origin: "register_flow") }

      it "renders without the start over link - there's nothing to abandon" do
        get register_path(b_param_token: b_param.id_token, step: 1)
        expect(response.status).to eq 200
        expect(response.body).to_not include "Start over"
      end
    end

    context "self-reported manufacturer" do
      let(:b_param) do
        BParam.create(origin: "register_flow",
          params: {bike: {owner_email:, manufacturer_id: Manufacturer.other.id, manufacturer_other: "Fancy Cycles"}}.as_json)
      end

      it "renders with the free text" do
        get register_path(b_param_token: b_param.id_token, step: 1)
        expect(response.status).to eq 200
        expect(response.body).to include "Fancy Cycles"
      end
    end

    context "unknown token" do
      it "redirects to the start" do
        get register_path(b_param_token: "unknown-token", step: 1)
        expect(response).to redirect_to new_register_path
        expect(flash[:notice]).to be_present
      end
    end
  end

  describe "create" do
    let!(:empty_b_param) { BParam.create(origin: "register_flow") }
    let(:step_1_params) { {b_param: {manufacturer_id: "Trek", cycle_type: "cargo", owner_email:}} }
    let(:create_params) { step_1_params.merge(b_param_token: empty_b_param.id_token) }

    it "saves step 1, emails the confirmation link and redirects to step 2" do
      expect { post base_url, params: create_params }
        .to change(Email::RegisterConfirmationJob.jobs, :size).by 1
      expect(BParam.count).to eq 1
      expect(Email::PartialRegistrationJob.jobs.size).to eq 0
      empty_b_param.reload
      expect(empty_b_param.email_confirmation_token).to be_present
      expect(empty_b_param).to have_attributes(origin: "register_flow", owner_email:,
        manufacturer_id: manufacturer.id, creator_id: nil, cycle_type: "cargo")
      expect(empty_b_param.motorized?).to be_falsey
      expect(response).to redirect_to register_path(b_param_token: empty_b_param.id_token, step: 2)
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
      it "builds a registration rather than losing the submission" do
        expect {
          post base_url, params: step_1_params.merge(b_param_token: "unknown-token")
        }.to change(BParam, :count).by 1
        built_b_param = BParam.last
        expect(built_b_param).to have_attributes(origin: "register_flow", owner_email:,
          manufacturer_id: manufacturer.id, cycle_type: "cargo")
        expect(response).to redirect_to register_path(b_param_token: built_b_param.id_token, step: 2)
      end

      context "with the organization_id from step 1's hidden field" do
        let(:organization) { FactoryBot.create(:organization) }

        it "keeps the organization on the built registration" do
          post base_url, params: step_1_params.merge(b_param_token: "unknown-token",
            organization_id: organization.slug)
          expect(BParam.last.creation_organization_id).to eq organization.id
        end
      end
    end
  end

  describe "show step: 2" do
    # Methods rather than let, since the examples re-request and re-check
    def status_field(field_name)
      Nokogiri::HTML(response.body).css("[data-register--status-fields-target='field']")
        .find { |el| el.at_css("[name^='bike[#{field_name}']") }
    end

    def phone_field_classes
      status_field("phone")["class"]
    end

    def phone_statuses_watched
      JSON.parse(status_field("phone")["data-statuses"])
    end

    def user_name_field
      Nokogiri::HTML(response.body).at_css("input[name='bike[user_name]']")
    end

    it "renders the details form, showing the email from step 1" do
      get register_path(b_param_token: b_param.id_token, step: 2)
      expect(response.status).to eq 200
      expect(response.body).to include "Add your bike"
      expect(response.body).to include owner_email
      # No organization asking for anything, so it's just the registrant's own info
      expect(response.body).to include "Contact info"
      # Anonymous, so there's no account the name could come from - and the browser
      # is what asks for it, no js involved
      expect(user_name_field["required"]).to eq "required"
      # An address nothing has proven yet, so the confirmation is still pending - the photo
      # is offered regardless, uploading against the registration's token
      expect(response.body).to include "confirmation link to your email"
      expect(response.body).to include "bike_image"

      # Confirming only clears the alert
      b_param.confirm_email!
      get register_path(b_param_token: b_param.id_token, step: 2)
      expect(response.body).to_not include "confirmation link to your email"
      # the shared upload component, rather than this page's own pair of buttons. The field
      # posts its own bytes as rendered; JS swaps that for the signed id it uploads to
      expect(response.body).to include "ui--forms--file-upload"
      expect(response.body).to include "bike[image]"
      expect(response.body).to include "bike[image_signed_id]"
    end

    it "hides the phone field, showing it for the statuses bikes/new does" do
      get register_path(b_param_token: b_param.id_token, step: 2)
      expect(phone_field_classes).to include "tw:hidden" # rendered, just collapsed
      # Only stolen and impounded reveal it, so those are what the controller watches
      expect(phone_statuses_watched).to eq %w[status_stolen status_impounded]

      b_param.update(params: b_param.params.deep_merge("bike" => {"status" => "status_stolen"}))
      get register_path(b_param_token: b_param.id_token, step: 2)
      expect(phone_field_classes).to_not include "tw:hidden"
    end

    context "with an organization" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:b_param) do
        BParam.create(origin: "register_flow",
          params: {bike: {owner_email:, manufacturer_id: "Trek", creation_organization_id: organization.id}}.as_json)
      end
      let(:reg_fields) { %w[bike[extra_registration_number] bike[organization_affiliation] bike[student_id]] }

      it "renders only the additional registration fields the organization enables" do
        get register_path(b_param_token: b_param.id_token, step: 2)
        reg_fields.each { |field| expect(response.body).to_not include field }
        # Not rendered at all - no status could reveal it, and it's ~300 option tags
        expect(status_field("address_record_attributes")).to be_nil
        # The Bike Index sticker isn't org-gated here, unlike bikes/new
        expect(response.body).to include "bike[bike_sticker]"
        # Nothing extra was asked for, so the section is just the registrant's own info
        expect(response.body).to include "Contact info"
        expect(response.body).to_not include "Information for"

        organization.update_column :enabled_feature_slugs,
          %w[reg_phone reg_extra_registration_number reg_organization_affiliation reg_student_id]
        get register_path(b_param_token: b_param.id_token, step: 2)
        reg_fields.each { |field| expect(response.body).to include field }
        expect(response.body).to include "Information for #{organization.short_name}"
        expect(response.body).to_not include "Contact info"
        # reg_phone shows it regardless of the status, so nothing to toggle
        expect(phone_field_classes).to_not include "tw:hidden"
        expect(phone_statuses_watched).to eq Bike.statuses
        expect(response.body).to include "#{organization.short_name} affiliation"
      end

      it "saves the additional registration fields" do
        organization.update_column :enabled_feature_slugs, %w[reg_extra_registration_number reg_student_id]
        patch base_url, params: {b_param_token: b_param.id_token,
                                 bike: {primary_frame_color_id: color.id, status: "status_with_owner",
                                        extra_registration_number: "XX99", organization_affiliation: "student",
                                        student_id: "S-1234", user_name:,
                                        address_record_attributes: {street: "1 Main St", city: "Chicago",
                                                                    postal_code: "60608", country_id: Country.united_states_id}}}
        expect(b_param.reload.bike).to include("extra_registration_number" => "XX99",
          "organization_affiliation" => "student", "student_id" => "S-1234")
        # Passed through as the nested attributes BikeServices::Creator assigns on the bike
        expect(b_param.bike["address_record_attributes"]).to include("street" => "1 Main St", "city" => "Chicago")
      end

      context "reg_address" do
        def address_street_field
          Nokogiri::HTML(response.body).at_css("[name='bike[address_record_attributes][street]']")
        end

        it "shows the address fields, except for statuses with their own address record" do
          organization.update_column :enabled_feature_slugs, ["reg_address"]
          get register_path(b_param_token: b_param.id_token, step: 2)
          expect(status_field("address_record_attributes")["class"]).to_not include "tw:hidden"
          watched = JSON.parse(status_field("address_record_attributes")["data-statuses"])
          expect(watched).to include "status_with_owner"
          expect(watched).to_not include "status_stolen"
          expect(watched).to_not include "status_impounded"
          expect(response.body).to include "Information for #{organization.short_name}"

          b_param.update(params: b_param.params.deep_merge("bike" => {"status" => "status_stolen"}))
          get register_path(b_param_token: b_param.id_token, step: 2)
          expect(status_field("address_record_attributes")["class"]).to include "tw:hidden"
        end

        it "only requires the address when the organization requires it" do
          organization.update_column :enabled_feature_slugs, ["reg_address"]
          get register_path(b_param_token: b_param.id_token, step: 2)
          expect(address_street_field["required"]).to be_nil

          organization.update_column :enabled_feature_slugs, %w[reg_address require_reg_address]
          get register_path(b_param_token: b_param.id_token, step: 2)
          expect(address_street_field["required"]).to eq "required"
        end
      end
    end

    context "signed in" do
      include_context :request_spec_logged_in_as_user

      it "shows the confirmation alert - and asks for the name of whoever it's for" do
        get register_path(b_param_token: b_param.id_token, step: 2)
        expect(response.status).to eq 200
        expect(response.body).to include "confirmation link to your email"
        expect(response.body).to include "bike_image"
        # Step 1's address isn't theirs, so their account's name isn't the one to use
        expect(user_name_field["required"]).to eq "required"
      end

      context "registering to their own address" do
        let(:owner_email) { current_user.email }

        it "skips the name and the alert - their account answers both" do
          get register_path(b_param_token: b_param.id_token, step: 2)
          expect(user_name_field).to be_nil
          expect(response.body).to_not include "confirmation link to your email"
        end
      end
    end

    context "step 1 not submitted" do
      let(:b_param) { BParam.create(origin: "register_flow") }

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
        expect(flash[:notice]).to be_present
      end
    end
  end

  describe "update" do
    let(:bike_details) do
      {primary_frame_color_id: color.id, serial_number: "XYZ 123", frame_size: "m",
       frame_model: "Marlin 7", year: "2023", phone: "(555) 000-0000", status: "status_with_owner",
       user_name:}
    end

    context "anonymous" do
      it "saves the details on the b_param without creating a bike" do
        expect {
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
        }.to_not change(Bike, :count)
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :finished)
        b_param.reload
        expect(BikeServices::Register.send(:details_completed?, b_param)).to be_truthy
        # IDs pass through as posted strings; they're cast when the bike is created
        expect(b_param.bike).to match_hash_indifferently(bike_details.merge(owner_email:,
          manufacturer_id: manufacturer.id, primary_frame_color_id: color.id.to_s))
        follow_redirect!
        expect(response.body).to include "Registration saved"
        expect(response.body).to include "verify your email"
        # Why the confirmation link is worth clicking
        expect(response.body).to include "Confirming your email lets you"
        expect(response.body).to include "Finish reporting your stolen bike"
      end

      context "with a photo" do
        let(:blob) do
          ActiveStorage::Blob.create_and_upload!(io: File.open(Rails.root.join("spec/fixtures/bike.jpg")),
            filename: "bike.jpg", content_type: "image/jpeg")
        end

        it "stores the direct upload's signed id, and keeps it when a later submit posts none" do
          patch base_url, params: {b_param_token: b_param.id_token,
                                   bike: bike_details.merge(image_signed_id: blob.signed_id)}
          expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :finished)
          expect(b_param.reload.image_signed_id).to eq blob.signed_id
          # It isn't a bike attribute, so it stays out of the bike params
          expect(b_param.bike.keys).to_not include "image_signed_id"

          patch base_url, params: {b_param_token: b_param.id_token,
                                   bike: bike_details.merge(image_signed_id: "")}
          expect(b_param.reload.image_signed_id).to eq blob.signed_id
        end

        # Without JS nothing strips the field's name, so it posts the bytes and there's no
        # signed id to go with them
        context "posting the bytes rather than a signed id" do
          let(:image) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/bike.jpg"), "image/jpeg") }

          it "stores the upload on the b_param" do
            patch base_url, params: {b_param_token: b_param.id_token,
                                     bike: bike_details.merge(image_signed_id: "", image:)}
            expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :finished)
            expect(b_param.reload.image).to be_present
            expect(b_param.image_signed_id).to be_blank
            # The upload isn't a bike attribute, so it stays out of the params json
            expect(b_param.params.to_json).to_not include "bike.jpg"
          end
        end
      end

      context "already completed" do
        it "redirects resubmissions to finished, saving nothing" do
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          expect {
            patch base_url, params: {b_param_token: b_param.id_token, bike: {serial_number: "changed"}}
          }.to_not change { b_param.reload.params }
          expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :finished)
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
          expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :finished)
        end
      end

      context "organization with an auto user" do
        let(:organization) { FactoryBot.create(:organization, :with_auto_user) }
        let(:b_param) do
          BParam.create(origin: "register_flow",
            params: {bike: {owner_email:, manufacturer_id: "Trek", creation_organization_id: organization.id}}.as_json)
        end

        it "creates the bike, BikeServices::Builder standing the auto user in as creator" do
          expect {
            patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          }.to change(Bike, :count).by 1
          expect(Bike.last.creator_id).to eq organization.auto_user_id
          # The name entered is who the registration is for, there being no account to take one from
          expect(Bike.last.owner_name).to eq user_name
        end
      end

      context "blank name" do
        it "re-renders step 2 with an error, saving the details but not completing" do
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details.merge(user_name: " ")}
          expect(response.status).to eq 422
          expect(response.body).to include "Owner name is required to register"
          expect(response.body).to include "XYZ 123"
          # Everything entered is kept, but incomplete - so the flow stays on step 2
          expect(b_param.reload.bike["serial_number"]).to eq "XYZ 123"
          expect(BikeServices::Register.send(:details_completed?, b_param)).to be_falsey
          expect(BikeServices::Register.permitted_step(b_param, "review", sequence: nil)).to eq "2"
        end
      end

      context "motorized" do
        let(:b_param) do
          BParam.create(origin: "register_flow",
            params: {bike: {owner_email:, manufacturer_id: "Trek"}, propulsion_type_motorized: "1"}.as_json)
        end

        it "completes directly, keeping motorized" do
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :finished)
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
        expect(bike.current_ownership.origin).to eq "register_flow"
        expect(b_param.reload.created_bike_id).to eq bike.id
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :finished)
        follow_redirect!
        expect(response.body).to include "Registration complete"
        # Registered for someone else, so it's theirs to claim rather than "your registration"
        expect(response.body).to include "so they can claim the registration"
        expect(response.body).to include "View the registration"
        expect(response.body).to_not include "keep watch"

        # Revisiting any step after completion redirects to finished
        get register_path(b_param_token: b_param.id_token, step: 2)
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :finished)
        get register_path(b_param_token: b_param.id_token, step: 1)
        expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :finished)
      end

      context "blank serial" do
        let(:bike_details) { {primary_frame_color_id: color.id, status: "status_with_owner", user_name:} }

        it "registers with an unknown serial" do
          expect {
            patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          }.to change(Bike, :count).by 1
          expect(Bike.last.serial_number).to eq "unknown"
        end
      end

      context "registering to their own address" do
        let(:owner_email) { current_user.email }

        it "completes without a name - their account is the one it takes" do
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details.except(:user_name)}
          expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: :finished)
          expect(Bike.last.owner_name).to eq current_user.name
          follow_redirect!
          # Their own registration, so the completion card is addressed to them
          expect(response.body).to include "keep watch"
          expect(response.body).to include "View your registration"
        end
      end

      context "b_param created by a different user" do
        let(:b_param) do
          BParam.create(origin: "register_flow", creator_id: FactoryBot.create(:user_confirmed).id,
            params: {bike: {owner_email:}}.as_json)
        end

        it "does not find the registration" do
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          expect(response).to redirect_to new_register_path
          expect(flash[:notice]).to be_present
        end
      end
    end

    context "unknown token" do
      it "errors - step 2 alone has nothing to build a registration from" do
        expect {
          patch base_url, params: {b_param_token: "unknown-token", bike: bike_details}
        }.to_not change(BParam, :count)
        expect(Bike.count).to eq 0
        expect(response).to redirect_to new_register_path
        expect(flash[:notice]).to be_present
      end
    end
  end

  describe "acknowledge" do
    let(:organization) { FactoryBot.create(:organization) }
    # Built as a draft and activated below, since activation freezes the pages
    let(:sequence) do
      FactoryBot.create(:registration_sequence, organization:,
        faq_url: "https://example.com/faq", acknowledgment_text: "agree to all of it")
    end
    let!(:battery_page) do
      FactoryBot.create(:registration_sequence_page, registration_sequence: sequence, listing_order: 0,
        title: "Battery & charging", subtitle: "Charge safely",
        heading: "Looks like you have an e-vehicle!",
        body: "<ul><li>Charge with the manufacturer's charger</li><li>Report a swollen battery</li></ul>")
    end
    let!(:campus_page) do
      FactoryBot.create(:registration_sequence_page, registration_sequence: sequence, listing_order: 1,
        title: "Campus rules", body: "<ul><li>Dismount in posted zones</li></ul>",
        organization_specific: true)
    end
    let(:b_param) do
      BParam.create(origin: "register_flow",
        params: {bike: {owner_email:, manufacturer_id: "Trek", cycle_type: "e-scooter",
                        creation_organization_id: organization.id}}.as_json)
    end
    let(:bike_details) do
      {primary_frame_color_id: color.id, serial_number: "XYZ 123", status: "status_with_owner", user_name:}
    end
    let(:step_path) { ->(step) { register_path(b_param_token: b_param.id_token, step:) } }

    include_context :request_spec_logged_in_as_user
    before { sequence.make_active! }

    it "walks the safety pages between the details and the bike" do
      # Step 2 hands off to the first safety page rather than creating the bike
      expect {
        patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
      }.to_not change(Bike, :count)
      expect(response).to redirect_to step_path.call("3")

      follow_redirect!
      # The heading is the page's own; the title labels its rules and names it on the review
      expect(response.body).to include "Looks like you have an e-vehicle!"
      expect(response.body).to include "Battery &amp; charging"
      expect(response.body).to include "Charge with the manufacturer's charger"
      expect(response.body).to include "Electric (motorized) detected"
      expect(response.body).to include "E-Vehicle Acknowledgment · Step 1 of 3"
      expect(response.body).to include "https://example.com/faq"

      # Ahead of where the registration stands clamps back to it
      get step_path.call("4")
      expect(response).to redirect_to step_path.call("3")

      patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "3",
                                                acknowledged: {"0" => "1", "1" => "1"}}
      expect(response).to redirect_to step_path.call("4")
      expect(BikeServices::Register.acknowledged_page_ids(b_param.reload)).to eq([battery_page.id])

      follow_redirect!
      expect(response.body).to include "Campus rules"
      # The organization owns this page's rules, so its name is on them
      expect(response.body).to include organization.short_name

      expect {
        patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "4",
                                                  acknowledged: {"0" => "1"}}
      }.to_not change(Bike, :count)
      expect(response).to redirect_to step_path.call("review")

      follow_redirect!
      expect(response.body).to include "You&#39;re almost done"
      expect(response.body).to include "agree to all of it"
      # The review is the last acknowledgment step, not a completed one - the
      # acknowledgment below it is still unsigned
      expect(response.body).to include "E-Vehicle Acknowledgment · Step 3 of 3"
      expect(response.body).to_not include "Safety check complete"
      # Registered for someone else, so it's their name that's agreeing - not the
      # signed-in account filling the form in
      expect(response.body).to include user_name
      expect(response.body).to_not include current_user.name

      # The acknowledgment is what creates the bike
      expect {
        patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "review", acknowledged_all: "1"}
      }.to change(Bike, :count).by(1).and change(RegistrationSequenceAcknowledgment, :count).by(1)
      expect(response).to redirect_to step_path.call("finished")
      expect(b_param.reload.created_bike_id).to eq Bike.last.id

      # The record hangs off the bike, so it survives the b_param being swept
      acknowledgment = RegistrationSequenceAcknowledgment.last
      expect(acknowledgment).to have_attributes(registration_sequence_id: sequence.id,
        bike_id: Bike.last.id, user_id: current_user.id, owner_email:,
        acknowledgment_text: "agree to all of it")
      expect(acknowledgment.acknowledged_pages.pluck(:id)).to match_array([battery_page.id, campus_page.id])
    end

    it "claims a registrant who signed in partway through the safety pages" do
      patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
      # As if the details had gone in before there was an account to attribute them to
      b_param.reload.update_column(:creator_id, nil)

      sequence.registration_sequence_pages.each_with_index do |page, index|
        patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: (index + 3).to_s,
                                                  acknowledged: page.bullets.each_index.to_h { [it.to_s, "1"] }}
      end
      expect {
        patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "review", acknowledged_all: "1"}
      }.to change(Bike, :count).by 1
      expect(Bike.last.creator_id).to eq current_user.id
    end

    it "advances one page at a time, even once the later ones are acknowledged" do
      patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
      patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "3",
                                                acknowledged: {"0" => "1", "1" => "1"}}
      patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "4",
                                                acknowledged: {"0" => "1"}}
      expect(response).to redirect_to step_path.call("review")

      # Revisiting the first page from the review and continuing walks forward
      # through the rest, rather than jumping straight back to the end
      patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "3",
                                                acknowledged: {"0" => "1", "1" => "1"}}
      expect(response).to redirect_to step_path.call("4")
    end

    it "refuses a page with a rule left unchecked" do
      patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
      patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "3",
                                                acknowledged: {"0" => "1"}}
      expect(flash[:error]).to be_present
      expect(response).to redirect_to step_path.call("3")
      expect(BikeServices::Register.acknowledged_page_ids(b_param.reload)).to eq([])
    end

    it "refuses an acknowledgment that skipped the pages" do
      patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
      expect {
        patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "review", acknowledged_all: "1"}
      }.to_not change(Bike, :count)
      # The review isn't reachable yet, so this lands back on the first page
      expect(response).to redirect_to step_path.call("3")
    end

    context "not an e-vehicle" do
      let(:b_param) do
        BParam.create(origin: "register_flow",
          params: {bike: {owner_email:, manufacturer_id: "Trek", cycle_type: "bike",
                          creation_organization_id: organization.id}}.as_json)
      end

      it "completes at step 2, with no safety pages" do
        expect {
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
        }.to change(Bike, :count).by 1
        expect(response).to redirect_to step_path.call("finished")
      end
    end
  end

  describe "acknowledge, anonymous" do
    let(:organization) { FactoryBot.create(:organization) }
    let!(:sequence) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }
    let(:b_param) do
      BParam.create(origin: "register_flow",
        params: {bike: {owner_email:, manufacturer_id: "Trek", cycle_type: "e-scooter",
                        creation_organization_id: organization.id}}.as_json)
    end
    let(:step_path) { ->(step) { register_path(b_param_token: b_param.id_token, step:) } }

    it "holds the registration for the confirmation email once everything is acknowledged" do
      patch base_url, params: {b_param_token: b_param.id_token,
                               bike: {primary_frame_color_id: color.id, serial_number: "XYZ 123",
                                      status: "status_with_owner", user_name: "Sally Rider"}}
      # No creator, but the safety pages still come before the completion page
      expect(response).to redirect_to step_path.call("3")

      sequence.registration_sequence_pages.each_with_index do |page, index|
        patch acknowledge_register_path, params: {b_param_token: b_param.id_token,
                                                  step: (index + 3).to_s,
                                                  acknowledged: page.bullets.each_index.to_h { [it.to_s, "1"] }}
      end
      expect(response).to redirect_to step_path.call("review")

      expect {
        patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "review", acknowledged_all: "1"}
      }.to_not change(Bike, :count)
      expect(response).to redirect_to step_path.call("finished")
      follow_redirect!
      expect(response.body).to include "Registration saved"

      # Nothing is browsable behind the completion page any more
      get step_path.call("3")
      expect(response).to redirect_to step_path.call("finished")
    end
  end

  describe "confirm" do
    let!(:token) { b_param.generate_email_confirmation_token! }
    let(:confirm_params) { {b_param_token: b_param.id_token, confirmation_token: token} }
    let(:step_path) { ->(step) { register_path(b_param_token: b_param.id_token, step:) } }

    it "renders a self-submitting form, then makes an account and signs them in" do
      get "#{base_url}/confirm", params: confirm_params
      expect(response.status).to eq 200
      expect(response.body).to include token
      # Rendering confirms nothing - a link scanner following the URL can't spend the token
      expect(b_param.reload.email_confirmed?).to be_falsey

      expect {
        post "#{base_url}/confirm_email", params: confirm_params
      }.to change(User, :count).by 1
      expect(b_param.reload).to have_attributes(email_confirmed?: true,
        email_confirmation_token: nil, creator_id: User.last.id)
      expect(User.last).to have_attributes(email: owner_email, confirmed: true)
      expect(User.last.last_login_at).to be_within(2.seconds).of Time.current
      # Dropped on the step the registration is on - and signed in, so nothing's pending
      expect(response).to redirect_to step_path.call("2")
      follow_redirect!
      expect(response.body).to_not include "confirmation link to your email"

      # Single use, so a forwarded link can't sign anyone in again
      expect {
        post "#{base_url}/confirm_email", params: confirm_params
      }.to_not change(User, :count)
      expect(response).to redirect_to step_path.call("2")
    end

    context "wrong token" do
      let(:wrong_params) { confirm_params.merge(confirmation_token: "wrong-token") }

      it "confirms nothing, and emails a new link once the last one is old enough" do
        # The link went out moments ago, so this doesn't send a second
        expect { post "#{base_url}/confirm_email", params: wrong_params }
          .to_not change(Email::RegisterConfirmationJob.jobs, :size)
        expect(b_param.reload.email_confirmed?).to be_falsey
        expect(flash[:error]).to be_present
        expect(response).to redirect_to step_path.call("2")

        sent_at = Time.current - BikeServices::Register::CONFIRMATION_EMAIL_INTERVAL - 1.minute
        b_param.update(params: b_param.params.merge("email_confirmation_sent_at" => sent_at))
        expect { post "#{base_url}/confirm_email", params: wrong_params }
          .to change(Email::RegisterConfirmationJob.jobs, :size).by 1
      end
    end

    context "unknown registration" do
      it "starts a new registration" do
        post "#{base_url}/confirm_email", params: confirm_params.merge(b_param_token: "unknown-token")
        expect(response).to redirect_to new_register_path
      end
    end

    context "registration waiting on the email" do
      let(:bike_details) do
        {primary_frame_color_id: color.id, serial_number: "XYZ 123",
         status: "status_with_owner", user_name:}
      end
      before { patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details} }

      it "creates the bike the registration was holding, and lands on finished" do
        expect(response).to redirect_to step_path.call("finished")

        expect {
          post "#{base_url}/confirm_email", params: confirm_params
        }.to change(Bike, :count).by 1
        expect(Bike.last).to have_attributes(owner_email:, serial_number: "XYZ 123",
          creator_id: User.last.id)
        expect(b_param.reload.created_bike_id).to eq Bike.last.id
        expect(response).to redirect_to step_path.call("finished")
        follow_redirect!
        expect(response.body).to include "Registration complete"
      end

      context "signed in as someone else" do
        include_context :request_spec_logged_in_as_user

        it "keeps their session, creating the bike for the confirmed address" do
          # The registration parked before they signed in, so it's still waiting here
          expect(b_param.reload.created_bike_id).to be_nil
          expect {
            post "#{base_url}/confirm_email", params: confirm_params
          }.to change(Bike, :count).by 1
          # No account for the confirmed address - they're still signed in as themselves
          expect(User.count).to eq 1
          expect(Bike.last).to have_attributes(owner_email:, creator_id: current_user.id)
          expect(flash[:info]).to be_present
          expect(response).to redirect_to step_path.call("finished")
        end
      end
    end
  end
end
