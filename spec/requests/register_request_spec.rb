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

  # Where Register::Step1::Component's start over link goes - it names the registration
  # it was rendered on, rather than leaving it to the session
  def start_over_path(b_param, **params)
    new_register_path(discard_token: b_param.id_token, **params)
  end

  def submit_button_style
    Nokogiri::HTML(response.body).at_css("form button[type=submit]")["style"]
  end

  describe "new" do
    it "creates an empty registration and redirects to its step 1" do
      expect { get "/register/new" }.to change(BParam, :count).by 1
      new_b_param = BParam.last
      expect(new_b_param.origin).to eq "register_flow"
      expect(response).to redirect_to register_path(b_param_token: new_b_param.id_token, step: 1)

      # new always starts one, whatever the session is holding - the bare /register is
      # what goes back to a registration in progress
      expect { get "/register/new" }.to change(BParam, :count).by 1
      expect(BParam.last.id).to_not eq new_b_param.id
      expect(response).to redirect_to register_path(b_param_token: BParam.last.id_token, step: 1)
    end

    context "status and organization params" do
      let(:organization) { FactoryBot.create(:organization) }

      it "stores them on the registration it creates" do
        # The slug resolves to the organization, rather than being stored as-is
        get "/register/new?status=stolen&organization_id=#{organization.slug}"
        stolen_b_param = BParam.last
        expect(stolen_b_param).to have_attributes(status: "status_stolen",
          creation_organization_id: organization.id, organization_id: organization.id)

        # Each visit starts its own, so what this is comes from the link rather than
        # from whatever the session was left on
        get "/register/new?status=found"
        expect(BParam.last.id).to_not eq stolen_b_param.id
        expect(BParam.last.status).to eq "status_impounded"

        get "/register/new"
        expect(BParam.last.status).to eq "status_with_owner" # the default, not the last link's
      end

      # ?status=stolen, ?status=found and ?stolen=true, not just the full enum value
      it "takes the shorthand every other entry point takes" do
        {"status=stolen" => "status_stolen", "status=found" => "status_impounded",
         "stolen=true" => "status_stolen", "status=status_impounded" => "status_impounded",
         "status=nonsense" => "status_with_owner"}.each do |query, expected|
          get "/register/new?discard_token=#{BParam.last&.id_token}&#{query}"
          expect(BParam.last.status).to eq(expected), "#{query} gave #{BParam.last.status}"
        end
      end

      # The organization's link is /register, which has no registration to attach to yet
      it "keeps the organization through the bare /register" do
        get "#{base_url}?organization_id=#{organization.slug}"
        follow_redirect! # into /register/new, which creates the registration
        expect(BParam.last.creation_organization_id).to eq organization.id
      end

      # The organized add-a-bike page links here with its slug, and a member is as likely
      # to have one going as not
      it "attaches the organization to the registration /register goes back to" do
        get "/register/new"
        b_param = BParam.last
        expect(b_param.creation_organization_id).to be_blank

        expect { get "#{base_url}?organization_id=#{organization.slug}" }.to_not change(BParam, :count)
        expect(b_param.reload.creation_organization_id).to eq organization.id
      end
    end

    context "signed in, with no organization named" do
      include_context :request_spec_logged_in_as_user
      let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }

      it "assigns nothing - they're in no organization and have no registrations" do
        get "/register/new"
        expect(BParam.last.creation_organization_id).to be_blank
        expect(BParam.last.auto_organization_id).to be_blank
      end

      context "a member of one organization" do
        let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user: current_user, organization:) }

        it "registers with it, and step 1 names it" do
          get "/register/new"
          expect(BParam.last).to have_attributes(creation_organization_id: organization.id,
            auto_organization_id: organization.id, organization_id: organization.id)
          follow_redirect!
          expect(response.body).to include "Brakebills"
        end
      end

      context "a member of two organizations" do
        let(:other_organization) { FactoryBot.create(:organization) }
        let!(:organization_roles) do
          [organization, other_organization]
            .map { FactoryBot.create(:organization_role_claimed, user: current_user, organization: it) }
        end

        # Which of the two is answered by the one they're acting as, rather than left unassigned
        it "registers with the passive organization" do
          expect(OrganizationRole.default_organization(current_user)).to eq organization
          get "/register/new"
          expect(BParam.last.auto_organization_id).to eq organization.id

          # Visiting the other organization's pages is what makes it the passive one
          get "/o/#{other_organization.to_param}"
          get start_over_path(BParam.last)
          expect(BParam.last.auto_organization_id).to eq other_organization.id
        end
      end

      context "their other bike is registered with an organization" do
        let!(:bike) do
          FactoryBot.create(:bike_organized, :with_ownership_claimed,
            creation_organization: organization, user: current_user)
        end

        it "registers with that organization" do
          get "/register/new"
          expect(BParam.last.auto_organization_id).to eq organization.id
        end
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

      # Each one waiting goes on alerting its creator to come back to a registration
      # they've moved on from
      it "leaves two waiting at most - the most recent, and the one it starts" do
        older = FactoryBot.create(:b_param_unfinished_registration, creator: current_user,
          updated_at: Time.current - 1.hour)
        most_recent = FactoryBot.create(:b_param_unfinished_registration, creator: current_user)

        # One destroyed, one started
        expect { get "/register/new" }.to_not change(BParam, :count)
        expect(BParam.where(id: older.id)).to be_empty
        expect(BParam.where(id: most_recent.id)).to be_present
        expect(current_user.b_params.unfinished_registrations.count).to eq 1
      end

      # Registering for themselves, which is what raises the alert start over resolves
      it "destroys the submitted registration start over leaves, resolving its alert" do
        get "/register/new"
        discarded = BParam.last
        post base_url, params: {b_param_token: discarded.id_token,
                                b_param: {manufacturer_id: "Trek", cycle_type: "bike",
                                          owner_email: current_user.email}}
        expect(discarded.reload.unfinished_registration?).to be_truthy
        expect(current_user.user_alerts.active.unfinished_registration.count).to eq 1
        expect(current_user.reload.alert_slugs).to eq ["unfinished_registration"]

        # One destroyed, one created
        expect { get start_over_path(discarded) }.to_not change(BParam, :count)
        expect(BParam.where(id: discarded.id)).to be_empty
        expect(current_user.user_alerts.active.unfinished_registration.count).to eq 0

        # show_general_alert reads the slugs, so resolving the alert isn't enough on its own
        expect(current_user.reload.alert_slugs).to eq []
        get "/my_account"
        expect(assigns(:show_general_alert)).to be_falsey
        expect(response.body).to_not include "isn't registered yet!"
      end

      # The link names the registration it was rendered on, which the session has since
      # moved off of - register/new only ever resumes the one the session is holding
      it "discards the registration start over was rendered on, not the session's" do
        first_tab = FactoryBot.create(:b_param_unfinished_registration, creator: current_user)

        expect { get "/register/new" }.to change(BParam, :count).by 1
        second_tab = BParam.last
        expect(session[:register_b_param_token]).to eq second_tab.id_token

        # Start over from the first tab's step 1, with the session on the second tab's
        # - one destroyed, one created
        expect { get start_over_path(first_tab) }.to_not change(BParam, :count)
        expect(BParam.where(id: first_tab.id)).to be_empty
        expect(BParam.where(id: second_tab.id)).to be_present
        # A blank step 1 either way, rather than dropping them onto the second tab's
        expect(BParam.last.id).to_not eq second_tab.id
      end
    end

    context "email param" do
      # Signed out there's no address to blank, so false is the signed-in context's to cover
      it "uses the passed address on the registration it starts" do
        get "/register/new?email=someone@example.com"
        passed = BParam.last
        expect(passed.owner_email).to eq "someone@example.com"

        # Each visit starts its own, so the next one doesn't inherit the address
        get "/register/new"
        expect(BParam.last.id).to_not eq passed.id
        expect(BParam.last.owner_email).to be_nil
      end

      context "signed in" do
        include_context :request_spec_logged_in_as_user

        it "prefers the passed address over the user's, and false over both" do
          get "/register/new?email=false"
          expect(BParam.last.owner_email).to be_nil

          get "/register/new?email=someone@example.com"
          expect(BParam.last.owner_email).to eq "someone@example.com"

          get start_over_path(BParam.last)
          expect(BParam.last.owner_email).to eq current_user.email
        end
      end
    end

    it "starts a fresh registration with the start over link, destroying the session's" do
      get "/register/new"
      session_b_param = BParam.last
      # One destroyed, one created
      expect { get start_over_path(session_b_param) }.to_not change(BParam, :count)
      expect(BParam.where(id: session_b_param.id)).to be_empty
      expect(response).to redirect_to register_path(b_param_token: BParam.last.id_token, step: 1)

      # The new registration is now the session's, which the bare /register goes back to
      expect { get base_url }.to_not change(BParam, :count)
      expect(response).to redirect_to register_path(b_param_token: BParam.last.id_token, step: 1)
    end

    # The emailed link is the only way an anonymous registration finishes, so start
    # over leaves the registration that link resumes
    it "keeps the registration once its confirmation email is out" do
      get "/register/new"
      emailed = BParam.last
      post base_url, params: {b_param_token: emailed.id_token,
                              b_param: {manufacturer_id: "Trek", cycle_type: "bike", owner_email:}}
      expect(emailed.reload.email_confirmation_sent_at).to be_present

      expect { get start_over_path(emailed) }.to change(BParam, :count).by 1
      expect(BParam.where(id: emailed.id)).to be_present
      expect(response).to redirect_to register_path(b_param_token: BParam.last.id_token, step: 1)
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

      # At the step it reached, rather than back to the start of it
      session_b_param.clean_params({bike: {manufacturer_id: manufacturer.id, owner_email:}}.as_json)
      session_b_param.save
      expect { get base_url }.to_not change(BParam, :count)
      expect(response).to redirect_to register_path(b_param_token: session_b_param.id_token, step: 2)
    end
  end

  describe "embed" do
    let(:organization) { FactoryBot.create(:organization) }

    it "renders step 1 for the frame, on a registration the submission carries out of it" do
      expect { get "/register/embed?organization_id=#{organization.slug}" }.to change(BParam, :count).by 1
      expect(response.status).to eq 200
      expect(BParam.last.creation_organization_id).to eq organization.id

      expect(response.body).to start_with("<!DOCTYPE html>")
      expect(response.body).to_not include("primary-header-nav")
      # The form's own styling, which nothing renders around it
      expect(response.body).to match(/<link[^>]*stylesheet[^>]*tailwind/)
      expect(response.body).to match(/<link[^>]*stylesheet[^>]*hotwire_combobox/)
      expect(response.body).to match(/<form[^>]*target="_top"/)
      expect(response.body).to match(/<form[^>]*data-turbo="false"/)
      expect(response.body).to include('name="robots" content="noindex"')

      # The session's still-blank registration, rather than one per view
      expect { get "/register/embed?organization_id=#{organization.slug}" }.to_not change(BParam, :count)
    end

    it "colors the button with the frame's ?button=, which the flow's own pages ignore" do
      get "/register/embed?organization_id=#{organization.slug}&button=c9a227"
      expect(submit_button_style).to include("background-color: #c9a227", "--button-hover-color: #a78620")

      # The derived shade, unless the frame names the one it wants
      get "/register/embed?organization_id=#{organization.slug}&button=c9a227&button_hover=123456"
      expect(submit_button_style).to include("--button-hover-color: #123456")

      get register_path(b_param_token: BParam.last.id_token, step: 1, button: "c9a227")
      expect(submit_button_style).to be_nil
    end
  end

  describe "show step: 1" do
    it "renders" do
      get register_path(b_param_token: b_param.id_token, step: 1)
      expect(response.status).to eq 200
      expect(response.body).to include "Register your vehicle!"
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

      context "with their own unfinished registration" do
        let!(:unfinished) do
          BParam.create(origin: "register_flow", creator: current_user,
            params: {bike: {owner_email: current_user.email, manufacturer_id: "Trek"}}.as_json)
        end

        it "doesn't show the general alert" do
          expect(current_user.reload.alert_slugs).to eq ["unfinished_registration"]

          get register_path(b_param_token: b_param.id_token, step: 1)

          expect(assigns(:show_general_alert)).to be_falsey
          expect(response.body).to_not include "isn't registered yet!"
        end

        it "shows it everywhere else" do
          get "/my_account"

          expect(assigns(:show_general_alert)).to be_truthy
          # Trek matches no manufacturer here, so step 1's name comes back off Other
          expect(response.body).to include "Your Trek bike isn't registered yet!"
          expect(response.body).to include register_path(b_param_token: unfinished.id_token)
        end
      end
    end

    context "with an organization" do
      let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
      let(:b_param) do
        BParam.create(origin: "register_flow",
          params: {bike: {owner_email:, cycle_type: "cargo", creation_organization_id: organization.id}}.as_json)
      end

      it "names the organization in the heading, and the cycle type only where js can swap it" do
        get register_path(b_param_token: b_param.id_token, step: 1)
        expect(response.body).to include "Register your vehicle with Brakebills!"
        expect(response.body).to include '<span data-register--heading-target="cycleType">cargo bike</span> info'
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
          expect(start_over).to eq start_over_path(b_param,
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
        .to change(Email::PartialRegistrationJob.jobs, :size).by 1
      expect(BParam.count).to eq 1
      expect(Email::PartialRegistrationJob).to have_enqueued_sidekiq_job(empty_b_param.id, "partial_register_confirmation")
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
      Nokogiri::HTML(response.body).css("[data-register--status-fields-target~='field']")
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

    # The button says what it does: a theft is reported after this form, so it doesn't
    # finish the registration the way an ordinary one does
    def submit_label
      Nokogiri::HTML(response.body).at_css("[data-register--status-fields-target='submitLabel']")
    end

    it "submits to the report rather than completing, for a registration that reports" do
      get register_path(b_param_token: b_param.id_token, step: 2)
      expect(submit_label.text.strip).to eq "Complete Bike Registration"
      # Picked in this form, so register--status-fields rechecks it against these
      expect(JSON.parse(submit_label["data-texts"]).select { |_status, text| text == "Next" }.keys)
        .to eq %w[status_stolen status_impounded]

      b_param.update(params: b_param.params.deep_merge("bike" => {"status" => "status_stolen"}))
      get register_path(b_param_token: b_param.id_token, step: 2)
      expect(submit_label.text.strip).to eq "Next"
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

    # A theft or a find is contacted on it, so those two ask for a phone rather than
    # offering one - and the status that decides which is picked in this form
    it "requires the phone for a theft or a find, saying which" do
      get register_path(b_param_token: b_param.id_token, step: 2)
      phone_field = status_field("phone")
      expect(phone_field.at_css("input[name='bike[phone]']")["required"]).to be_blank
      expect(phone_field.at_css("[data-optional-marker]")["hidden"]).to be_blank
      expect(phone_field.at_css("[data-required-marker]")["hidden"]).to be_present
      expect(phone_field.at_css("[data-required-helper]")["hidden"]).to be_present
      expect(JSON.parse(phone_field["data-texts"]))
        .to eq("status_stolen" => "Phone is required to register a stolen bike",
          "status_impounded" => "Phone is required to register a found bike")

      b_param.update(params: b_param.params.deep_merge("bike" => {"status" => "status_stolen"}))
      get register_path(b_param_token: b_param.id_token, step: 2)
      phone_field = status_field("phone")
      expect(phone_field.at_css("input[name='bike[phone]']")["required"]).to be_present
      expect(phone_field.at_css("[data-optional-marker]")["hidden"]).to be_present
      expect(phone_field.at_css("[data-required-marker]")["hidden"]).to be_blank
      helper = phone_field.at_css("[data-required-helper]")
      expect(helper["hidden"]).to be_blank
      expect(helper.text.strip).to eq "Phone is required to register a stolen bike"
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
        expect(response.body).to include "Progress saved"
        expect(response.body).to include "verify your email"
        # Why the confirmation link is worth clicking - this one isn't a theft, so it's
        # the registration it finishes rather than a report
        expect(response.body).to include "Confirming your email lets you"
        expect(response.body).to include "Finish adding your bike to Bike Index"
        expect(response.body).to_not include "Finish reporting your stolen"
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

      # This flow permits no enum a bot could poison - cycle_type is friendly_found and
      # status is gated by BParam#status - but it creates the bike from whatever the
      # registration already holds, so a bad value can still arrive at Builder
      context "registration holding an invalid enum value" do
        let(:b_param) do
          BParam.create(origin: "register_flow",
            params: {bike: {owner_email:, manufacturer_id: "Trek", frame_material: "1"}}.as_json)
        end

        it "sends them back to step 2 with the error, rather than raising" do
          expect {
            patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          }.to_not change(Bike, :count)
          expect(flash[:error]).to match(/frame material/i)
          expect(response).to redirect_to register_path(b_param_token: b_param.id_token, step: 2)
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

      context "with an automatically assigned organization" do
        let(:organization) do
          FactoryBot.create(:organization, short_name: "Brakebills").tap do
            it.update_column :enabled_feature_slugs, %w[reg_student_id]
          end
        end
        let!(:organization_role) { FactoryBot.create(:organization_role_claimed, user: current_user, organization:) }
        let(:b_param) do
          BParam.create(origin: "register_flow", creator_id: current_user.id,
            params: {bike: {owner_email:, manufacturer_id: "Trek", creation_organization_id: organization.id},
                     auto_organization_id: organization.id}.as_json)
        end

        it "offers the organization checked, and registers with it" do
          get register_path(b_param_token: b_param.id_token, step: 2)
          checkbox = Nokogiri::HTML(response.body).at_css("input[name='register_with_organization']")
          expect(checkbox["checked"]).to be_present
          expect(response.body).to include "Register with Brakebills"

          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details,
                                   register_with_organization: "1"}
          expect(Bike.last.creation_organization_id).to eq organization.id
          expect(Bike.last.organizations.pluck(:id)).to eq([organization.id])
        end

        it "registers without the organization when it's unchecked" do
          expect {
            patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          }.to change(Bike, :count).by 1
          expect(b_param.reload.creation_organization_id).to be_blank
          expect(Bike.last.creation_organization_id).to be_blank
          expect(Bike.last.organizations.pluck(:id)).to eq([])
        end

        it "keeps offering it after it's dropped, so it can be taken back" do
          patch base_url, params: {b_param_token: b_param.id_token,
                                   bike: bike_details.merge(user_name: " ")}
          expect(response.status).to eq 422
          checkbox = Nokogiri::HTML(response.body).at_css("input[name='register_with_organization']")
          expect(checkbox["checked"]).to be_blank
          expect(response.body).to include "Register with Brakebills"
          # Collapsed rather than dropped, so checking the box again has it to bring back
          expect(response.body).to include "bike[student_id]"

          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details,
                                   register_with_organization: "1"}
          expect(Bike.last.creation_organization_id).to eq organization.id
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

  describe "report" do
    let(:bike_details) do
      {primary_frame_color_id: color.id, serial_number: "XYZ 123", status: "status_stolen",
       phone: "(555) 000-0000", user_name:}
    end
    let(:report_details) do
      {date: "2026-08-05T14:30", timezone: "America/Chicago", theft_description: "Cut lock",
       police_report_number: "42", locking_description: "U-lock", proof_of_ownership: "1",
       phone_for_users: "0", phone_for_shops: "1", phone_for_police: "1",
       address_record_attributes: {street: "1 Main St", city: "Chicago", postal_code: "60608",
                                   country_id: Country.united_states_id}}
    end
    def step_path(step) = register_path(b_param_token: b_param.id_token, step:)

    context "signed in" do
      include_context :request_spec_logged_in_as_user

      it "asks about the theft after step 2, and creates the bike with its stolen record" do
        expect {
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
        }.to_not change(Bike, :count)
        expect(response).to redirect_to step_path("report")
        follow_redirect!
        expect(response.body).to include "Report your stolen bike"
        expect(response.body).to include "report[police_report_number]"
        expect(response.body).to include "report[address_record_attributes][street]"
        # The theft is the last thing asked for, no organization pages to follow it
        expect(response.body).to include "Complete Bike Registration"

        expect {
          patch "#{base_url}/report", params: {b_param_token: b_param.id_token, report: report_details}
        }.to change(Bike, :count).by 1
        expect(response).to redirect_to step_path("finished")

        bike = Bike.last
        expect(bike).to have_attributes(owner_email:, status: "status_stolen")
        stolen_record = bike.current_stolen_record
        expect(stolen_record).to have_attributes(theft_description: "Cut lock",
          police_report_number: "42", locking_description: "U-lock", proof_of_ownership: true,
          phone_for_users: false, phone_for_shops: true, street: "1 Main St", city: "Chicago")
        # Entered in Chicago, rather than wherever the server happens to be
        expect(stolen_record.date_stolen).to be_within(1).of Time.parse("2026-08-05T19:30:00 UTC")
        # Step 2's phone is the stolen record's, so the report doesn't ask for it again
        expect(stolen_record.phone).to eq "5550000000"
      end

      context "found" do
        let(:bike_details) { super().merge(status: "status_impounded") }

        it "asks about the find, and creates the bike with its impound record" do
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          expect(response).to redirect_to step_path("report")
          follow_redirect!
          expect(response.body).to include "About the bike you found"
          expect(response.body).to include "report[impounded_description]"
          expect(response.body).to_not include "report[police_report_number]"

          expect {
            patch "#{base_url}/report", params: {b_param_token: b_param.id_token,
                                                 report: report_details.except(:police_report_number)
                                                   .merge(impounded_description: "Behind the library")}
          }.to change(Bike, :count).by 1
          impound_record = Bike.last.current_impound_record
          expect(impound_record).to have_attributes(impounded_description: "Behind the library",
            user_id: current_user.id)
          expect(impound_record.impounded_at).to be_within(1).of Time.parse("2026-08-05T19:30:00 UTC")
          expect(impound_record.address_record.street).to eq "1 Main St"
        end
      end

      context "without when and where" do
        it "re-renders the step with what was entered, and creates no bike" do
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          expect(response).to redirect_to step_path("report")

          expect {
            patch "#{base_url}/report", params: {b_param_token: b_param.id_token,
                                                 report: report_details.except(:date, :address_record_attributes)}
          }.to_not change(Bike, :count)
          expect(response).to have_http_status :unprocessable_entity
          expect(response.body).to include "Please tell us when it was stolen"
          expect(response.body).to include "Please tell us where it was stolen"
          # Saved anyway, so the re-render has the rest of the report
          expect(response.body).to include "Cut lock"

          expect {
            patch "#{base_url}/report", params: {b_param_token: b_param.id_token, report: report_details}
          }.to change(Bike, :count).by 1
        end
      end

      context "registered with the owner" do
        let(:bike_details) { super().merge(status: "status_with_owner") }

        it "has no report to make, so step 2 creates the bike" do
          expect {
            patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          }.to change(Bike, :count).by 1
          expect(response).to redirect_to step_path("finished")

          patch "#{base_url}/report", params: {b_param_token: b_param.id_token, report: report_details}
          expect(response).to redirect_to step_path("finished")
          expect(Bike.last.current_stolen_record).to be_blank
        end
      end

      # The safety pages sit between the report and the bike, which is the window to go back in
      context "the status changes after the report" do
        let(:organization) { FactoryBot.create(:organization) }
        let!(:sequence) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }
        let(:b_param) do
          BParam.create(origin: "register_flow", params: {bike: {owner_email:, manufacturer_id: "Trek",
                                                                 cycle_type: "e-scooter", creation_organization_id: organization.id}}.as_json)
        end

        it "carries on to the safety pages, with no theft to report on the way" do
          patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
          expect(response).to redirect_to step_path("report")
          patch "#{base_url}/report", params: {b_param_token: b_param.id_token, report: report_details}
          expect(response).to redirect_to step_path("3")

          patch base_url, params: {b_param_token: b_param.id_token,
                                   bike: bike_details.merge(status: "status_with_owner")}
          expect(response).to redirect_to step_path("3")
          expect(b_param.reload.status).to eq "status_with_owner"
        end
      end
    end

    context "anonymous" do
      let!(:token) { b_param.generate_email_confirmation_token! }

      it "waits for the confirmation email, then asks about the theft" do
        patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
        # Nothing to report until the address is proven - the flow parks on finished
        expect(response).to redirect_to step_path("finished")
        get step_path("report")
        expect(response).to redirect_to step_path("finished")

        expect {
          post "#{base_url}/confirm_email", params: {b_param_token: b_param.id_token,
                                                     confirmation_token: token}
        }.to_not change(Bike, :count)
        expect(response).to redirect_to step_path("report")

        expect {
          patch "#{base_url}/report", params: {b_param_token: b_param.id_token, report: report_details}
        }.to change(Bike, :count).by 1
        expect(Bike.last).to have_attributes(owner_email:, creator_id: User.last.id)
        expect(Bike.last.current_stolen_record.theft_description).to eq "Cut lock"
      end
    end

    context "details not entered" do
      it "redirects to the step the registration is on, saving nothing" do
        expect {
          patch "#{base_url}/report", params: {b_param_token: b_param.id_token, report: report_details}
        }.to_not change { b_param.reload.params }
        expect(response).to redirect_to step_path("2")
      end
    end

    context "unknown token" do
      it "redirects to the start" do
        patch "#{base_url}/report", params: {b_param_token: "unknown-token", report: report_details}
        expect(response).to redirect_to new_register_path
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
    def step_path(step) = register_path(b_param_token: b_param.id_token, step:)

    include_context :request_spec_logged_in_as_user
    before { sequence.make_active! }

    it "walks the safety pages between the details and the bike" do
      # Step 2 hands off to the first safety page rather than creating the bike
      expect {
        patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
      }.to_not change(Bike, :count)
      expect(response).to redirect_to step_path("3")

      follow_redirect!
      # The cycle type reads as it's stored, so no title leads with it and stays sentence case
      expect(response.body).to include "<title>Safety check for your e-scooter</title>"
      # The heading is the page's own; the title labels its rules and names it on the review
      expect(response.body).to include "Looks like you have an e-vehicle!"
      expect(response.body).to include "Battery &amp; charging"
      expect(response.body).to include "Charge with the manufacturer's charger"
      expect(response.body).to include "Electric (motorized) detected"
      expect(response.body).to include "E-Vehicle Acknowledgment · Step 1 of 3"
      expect(response.body).to include "https://example.com/faq"

      # Ahead of where the registration stands clamps back to it
      get step_path("4")
      expect(response).to redirect_to step_path("3")

      patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "3",
                                                acknowledged: {"0" => "1", "1" => "1"}}
      expect(response).to redirect_to step_path("4")
      expect(BikeServices::Register.acknowledged_page_ids(b_param.reload)).to eq([battery_page.id])

      follow_redirect!
      expect(response.body).to include "Campus rules"
      # The organization owns this page's rules, so its name is on them
      expect(response.body).to include organization.short_name

      expect {
        patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "4",
                                                  acknowledged: {"0" => "1"}}
      }.to_not change(Bike, :count)
      expect(response).to redirect_to step_path("review")

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
      expect(response).to redirect_to step_path("finished")
      expect(b_param.reload.created_bike_id).to eq Bike.last.id

      follow_redirect!
      expect(response.body).to include "<title>Your e-scooter registration</title>"
      # Which step a page shows is server state, so Turbo mustn't restore it from a snapshot
      expect(response.body).to include "<meta name=\"turbo-cache-control\" content=\"no-cache\">"

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
      expect(response).to redirect_to step_path("review")

      # Revisiting the first page from the review and continuing walks forward
      # through the rest, rather than jumping straight back to the end
      patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "3",
                                                acknowledged: {"0" => "1", "1" => "1"}}
      expect(response).to redirect_to step_path("4")
    end

    it "refuses a page with a rule left unchecked" do
      patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
      patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "3",
                                                acknowledged: {"0" => "1"}}
      expect(flash[:error]).to be_present
      expect(response).to redirect_to step_path("3")
      expect(BikeServices::Register.acknowledged_page_ids(b_param.reload)).to eq([])
    end

    it "refuses an acknowledgment that skipped the pages" do
      patch base_url, params: {b_param_token: b_param.id_token, bike: bike_details}
      expect {
        patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "review", acknowledged_all: "1"}
      }.to_not change(Bike, :count)
      # The review isn't reachable yet, so this lands back on the first page
      expect(response).to redirect_to step_path("3")
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
        expect(response).to redirect_to step_path("finished")
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
    def step_path(step) = register_path(b_param_token: b_param.id_token, step:)

    it "holds the registration for the confirmation email once everything is acknowledged" do
      patch base_url, params: {b_param_token: b_param.id_token,
                               bike: {primary_frame_color_id: color.id, serial_number: "XYZ 123",
                                      status: "status_with_owner", user_name: "Sally Rider"}}
      # No creator, but the safety pages still come before the completion page
      expect(response).to redirect_to step_path("3")

      sequence.registration_sequence_pages.each_with_index do |page, index|
        patch acknowledge_register_path, params: {b_param_token: b_param.id_token,
                                                  step: (index + 3).to_s,
                                                  acknowledged: page.bullets.each_index.to_h { [it.to_s, "1"] }}
      end
      expect(response).to redirect_to step_path("review")

      expect {
        patch acknowledge_register_path, params: {b_param_token: b_param.id_token, step: "review", acknowledged_all: "1"}
      }.to_not change(Bike, :count)
      expect(response).to redirect_to step_path("finished")
      follow_redirect!
      expect(response.body).to include "Progress saved"

      # Nothing is browsable behind the completion page any more
      get step_path("3")
      expect(response).to redirect_to step_path("finished")
    end
  end

  describe "confirm" do
    let!(:token) { b_param.generate_email_confirmation_token! }
    let(:confirm_params) { {b_param_token: b_param.id_token, confirmation_token: token} }
    def step_path(step) = register_path(b_param_token: b_param.id_token, step:)

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
      expect(User.last).to have_attributes(email: owner_email, confirmed: true, passwordless_user: true)
      expect(User.last.last_login_at).to be_within(2.seconds).of Time.current
      # An account they never signed up for, so they're offered a password
      expect(flash[:notice]).to include(translation_key: :signed_up)
      # Dropped on the step the registration is on - and signed in, so nothing's pending
      expect(response).to redirect_to step_path("2")
      follow_redirect!
      expect(response.body).to_not include "confirmation link to your email"

      # Single use, so a forwarded link can't sign anyone in again
      expect {
        post "#{base_url}/confirm_email", params: confirm_params
      }.to_not change(User, :count)
      expect(response).to redirect_to step_path("2")
    end

    context "wrong token" do
      let(:wrong_params) { confirm_params.merge(confirmation_token: "wrong-token") }

      it "confirms nothing, and emails a new link once the last one is old enough" do
        # The link went out moments ago, so this doesn't send a second
        expect { post "#{base_url}/confirm_email", params: wrong_params }
          .to_not change(Email::PartialRegistrationJob.jobs, :size)
        expect(b_param.reload.email_confirmed?).to be_falsey
        expect(flash[:error]).to be_present
        expect(response).to redirect_to step_path("2")

        sent_at = Time.current - BikeServices::Register::CONFIRMATION_EMAIL_INTERVAL - 1.minute
        b_param.update(params: b_param.params.merge("email_confirmation_sent_at" => sent_at))
        expect { post "#{base_url}/confirm_email", params: wrong_params }
          .to change(Email::PartialRegistrationJob.jobs, :size).by 1
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
        expect(response).to redirect_to step_path("finished")

        expect {
          post "#{base_url}/confirm_email", params: confirm_params
        }.to change(Bike, :count).by 1
        expect(Bike.last).to have_attributes(owner_email:, serial_number: "XYZ 123",
          creator_id: User.last.id)
        expect(b_param.reload.created_bike_id).to eq Bike.last.id
        expect(response).to redirect_to step_path("finished")
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
          expect(response).to redirect_to step_path("finished")
          follow_redirect!
          expect(response.body).to include "signed in as #{current_user.email}"
        end
      end
    end

    context "owner_email edited after the link went out" do
      let!(:other_user) { FactoryBot.create(:user_confirmed, email: "someone-else@example.com") }
      let(:step_1_params) { {b_param: {manufacturer_id: "Trek", cycle_type: "cargo", owner_email: other_user.email}} }

      it "doesn't confirm the address the token was never mailed to" do
        post base_url, params: step_1_params.merge(b_param_token: b_param.id_token)
        expect(b_param.reload.owner_email).to eq other_user.email

        expect { post "#{base_url}/confirm_email", params: confirm_params }
          .to_not change(User, :count)
        expect(b_param.reload.email_confirmed?).to be_falsey
        expect(flash[:error]).to be_present
        # Nobody signed in - the link only ever proved the address it was mailed to
        get "/my_account"
        expect(response.status).to eq 302
      end
    end

    context "unconfirmed account for the address" do
      let!(:unconfirmed_user) { FactoryBot.create(:user, email: owner_email) }

      it "confirms it, since the link proved the address" do
        expect { post "#{base_url}/confirm_email", params: confirm_params }
          .to_not change(User, :count)
        expect(unconfirmed_user.reload.confirmed).to be_truthy
        expect(response).to redirect_to step_path("2")

        # Actually signed in, rather than bounced to please_confirm_email
        get "/my_account"
        expect(response.status).to eq 200
      end
    end
  end
end
