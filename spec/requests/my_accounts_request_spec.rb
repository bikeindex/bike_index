require "rails_helper"

RSpec.describe MyAccountsController, type: :request do
  base_url = "/my_account"

  describe "show" do
    context "user not logged in" do
      it "redirects" do
        get base_url
        expect(response).to redirect_to(/users\/new/) # weird subdomain issue matching url directly otherwise
      end
    end

    describe "user_home" do
      it "redirects" do
        get "/user_home"
        expect(response).to redirect_to(my_account_path)
      end
    end

    context "user logged in" do
      include_context :request_spec_logged_in_as_user

      context "unconfirmed" do
        let(:current_user) { FactoryBot.create(:user) }
        it "redirects" do
          expect(current_user.confirmed?).to be_falsey
          get base_url
          expect(flash).to_not be_present
          expect(response).to redirect_to(please_confirm_email_users_path)
        end
      end

      context "confirmed" do
        context "with name" do
          let(:current_user) { FactoryBot.create(:user_confirmed, name: "Alexandra") }
          it "renders, includes special header tags" do
            expect(current_user.confirmed?).to be_truthy
            get base_url
            expect(response.status).to eq(200)
            expect(response).to render_template("show")
            expect(session[:passive_organization_id]).to eq "0"
            expect(assigns[:passive_organization]).to be_nil
            # Test some header tag properties
            html_response = response.body
            # This is from header tag helpers
            expect(html_response).to match(/<title>Alexandra on Bike Index</)
            # This is pulled from the translations file
            expect(html_response).to match(/<meta.*Your bikes on Bike Index/)
          end
        end
        context "with organization" do
          let(:organization) { FactoryBot.create(:organization) }
          let(:current_user) { FactoryBot.create(:organization_member, organization: organization) }
          it "sets passive_organization_id" do
            expect(current_user.authorized?(organization)).to be_truthy
            get base_url
            expect(response.status).to eq(200)
            expect(response).to render_template("show")
            expect(session[:passive_organization_id]).to eq organization.id
            expect(assigns[:passive_organization]).to eq organization
          end
        end
        context "with stuff" do
          let!(:bike1) { FactoryBot.create(:bike, :with_ownership_claimed, user: current_user) }
          let!(:bike2) { FactoryBot.create(:bike, :with_ownership_claimed, user: current_user) }
          let!(:lock) { FactoryBot.create(:lock, user: current_user) }
          it "renders and user things are assigned" do
            current_user.reload
            get base_url, params: {per_page: 1}
            expect(response.status).to eq(200)
            expect(response).to render_template("show")
            expect(assigns(:bikes).pluck(:id)).to eq([bike2.id])
            expect(assigns(:locks).pluck(:id)).to eq([lock.id])
          end
        end
        context "with lock with deleted manufacturer" do
          let(:lock) { FactoryBot.create(:lock, user: current_user) }
          it "renders and user things are assigned" do
            lock.manufacturer.destroy
            get base_url
            expect(response.status).to eq(200)
            expect(response).to render_template("show")
            expect(assigns(:locks).count).to eq 1
            expect(assigns(:locks).pluck(:id)).to eq([lock.id])
          end
        end
        context "with user_phone" do
          before { current_user.update_column :alert_slugs, ["phone_waiting_confirmation"] }
          it "renders with show_general_alert" do
            get base_url

            expect(response).to be_ok
            expect(assigns(:show_general_alert)).to be_truthy
            expect(response).to render_template("show")
          end
        end
      end
    end
  end

  describe "/edit" do
    include_context :request_spec_logged_in_as_user
    let(:default_edit_templates) { {root: "User Settings", password: "Password", sharing: "Sharing + Personal Page"} }
    context "no page given" do
      it "renders root" do
        get "#{base_url}/edit"
        expect(response).to be_ok
        expect(assigns(:edit_template)).to eq("root")
        expect(assigns(:edit_templates)).to eq default_edit_templates.as_json
        expect(response).to render_template("edit")
        expect(response).to render_template(partial: "_root")
        expect(response).to render_template("layouts/application")
      end
    end
    context "application layout" do
      %w[root password sharing].each do |template|
        context template do
          it "renders the template" do
            get "#{base_url}/edit/#{template}"
            expect(response).to be_ok
            expect(assigns(:edit_template)).to eq(template)
            expect(assigns(:edit_templates)).to eq default_edit_templates.as_json
            expect(response).to render_template(partial: "_#{template}")
            expect(response).to render_template("layouts/application")
          end
        end
      end
    end
    context "with user_registration_organization" do
      let(:target_templates) { default_edit_templates.merge(registration_organizations: "Registration Organizations") }
      let!(:user_registration_organization) { FactoryBot.create(:user_registration_organization, user: current_user) }
      it "includes user_registration_organization template" do
        expect(current_user.reload.user_registration_organizations.pluck(:id)).to eq([user_registration_organization.id])
        get "#{base_url}/edit"
        expect(response).to be_ok
        expect(assigns(:edit_template)).to eq("root")
        expect(assigns(:edit_templates)).to eq target_templates.as_json
        expect(response).to render_template(partial: "_root")
        get "#{base_url}/edit/registration_organizations"
        expect(response).to be_ok
        expect(assigns(:edit_template)).to eq("registration_organizations")
        expect(assigns(:edit_templates)).to eq target_templates.as_json
        expect(response).to render_template(partial: "_registration_organizations")
        expect(response).to render_template("layouts/application")
      end
    end
  end

  describe "update" do
    include_context :request_spec_logged_in_as_user
    let!(:current_user) { FactoryBot.create(:user_confirmed, password: "old_password", password_confirmation: "old_password", username: "something") }
    # force skip_update to be false, like it is in reality
    before { current_user.skip_update = false }

    context "nil username" do
      it "doesn't update username" do
        current_user.reload
        expect(current_user.username).to eq "something"
        expect {
          patch base_url, params: {id: current_user.username, user: {username: " ", name: "tim"}, edit_template: "sharing"}
        }.to change(AfterUserChangeWorker.jobs, :size).by(1)
        expect(assigns(:edit_template)).to eq("sharing")
        current_user.reload
        expect(current_user.username).to eq("something")
      end
    end

    it "updates notification" do
      expect(current_user.notification_unstolen).to be_truthy # Because it's set to true by default
      expect {
        patch base_url, params: {id: current_user.username, user: {notification_newsletters: "1", notification_unstolen: "0"}}
      }.to change(AfterUserChangeWorker.jobs, :size).by(1)
      expect(response).to redirect_to edit_my_account_url
      current_user.reload
      expect(current_user.notification_newsletters).to be_truthy
      expect(current_user.notification_unstolen).to be_falsey
    end

    it "doesn't update user if current password not present" do
      patch base_url, params: {
        id: current_user.username,
        user: {
          password: "new_password",
          password_confirmation: "new_password"
        }
      }
      expect(current_user.reload.authenticate("new_password")).to be_falsey
    end

    it "doesn't update user if password doesn't match" do
      patch base_url, params: {
        id: current_user.username,
        user: {
          current_password: "old_password",
          password: "new_password",
          name: "Mr. Slick",
          password_confirmation: "new_passwordd"
        }
      }
      expect(current_user.reload.authenticate("new_password")).to be_falsey
      expect(current_user.name).not_to eq("Mr. Slick")
    end

    context "setting address" do
      let(:country) { Country.united_states }
      let(:state) { FactoryBot.create(:state, name: "New York", abbreviation: "NY") }
      it "sets address, geocodes" do
        current_user.reload
        expect(current_user.address_set_manually).to be_falsey
        expect(current_user.notification_newsletters).to be_falsey
        put base_url, params: {
          id: current_user.username,
          user: {
            name: "Mr. Slick",
            country_id: country.id,
            state_id: state.id,
            city: "New York",
            street: "278 Broadway",
            zipcode: "10007",
            notification_newsletters: "1",
            phone: "3223232"
          }
        }
        expect(response).to redirect_to(edit_my_account_url)
        expect(flash[:error]).to_not be_present
        current_user.reload
        expect(current_user.name).to eq("Mr. Slick")
        expect(current_user.country).to eq country
        expect(current_user.state).to eq state
        expect(current_user.street).to eq "278 Broadway"
        expect(current_user.zipcode).to eq "10007"
        expect(current_user.notification_newsletters).to be_truthy
        expect(current_user.latitude).to eq default_location[:latitude]
        expect(current_user.longitude).to eq default_location[:longitude]
        expect(current_user.phone).to eq "3223232"
        expect(current_user.address_set_manually).to be_truthy
      end
    end

    describe "updating phone" do
      it "updates and adds the phone" do
        current_user.reload
        expect(current_user.phone).to be_blank
        expect(current_user.user_phones.count).to eq 0
        Sidekiq::Worker.clear_all
        VCR.use_cassette("users_controller-update_phone", match_requests_on: [:path]) do
          Sidekiq::Testing.inline! {
            put base_url, params: {id: current_user.id, user: {phone: "15005550006"}}
          }
        end
        expect(flash[:success]).to be_present
        current_user.reload
        expect(current_user.phone).to eq "15005550006"
        expect(current_user.user_phones.count).to eq 1
        expect(current_user.phone_waiting_confirmation?).to be_truthy
        expect(current_user.alert_slugs).to eq(["phone_waiting_confirmation"])

        user_phone = current_user.user_phones.reorder(:created_at).last
        expect(user_phone.phone).to eq "15005550006"
        expect(user_phone.confirmed?).to be_falsey
        expect(user_phone.confirmation_code).to be_present
        expect(user_phone.notifications.count).to eq 1
      end
      context "without background" do
        it "still shows general alert" do
          current_user.reload
          expect(current_user.phone).to be_blank
          expect(current_user.user_phones.count).to eq 0
          patch base_url, params: {id: current_user.id, user: {phone: "15005550006"}}
          expect(flash[:success]).to be_present
          current_user.reload
          expect(current_user.phone).to eq "15005550006"
          expect(current_user.user_phones.count).to eq 0
          expect(current_user.alert_slugs).to eq(["phone_waiting_confirmation"])
        end
      end
    end
    context "previous password was too short" do
      # Prior to #1738 password requirement was 8 characters.
      # Ensure users who had valid passwords for the previous requirements can update their password
      it "updates password" do
        current_user.update_attribute :password, "old_pass"
        expect(current_user.reload.authenticate("old_pass")).to be_truthy
        patch base_url, params: {
          user: {
            current_password: "old_pass",
            password: "172ddfasdf1LDF",
            name: "Mr. Slick",
            password_confirmation: "172ddfasdf1LDF"
          }
        }
        expect(response).to redirect_to edit_my_account_path
        expect(flash[:success]).to be_present
        current_user.reload
        expect(current_user.reload.authenticate("172ddfasdf1LDF")).to be_truthy
      end
    end

    context "organization with hotsheet" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features, :in_nyc, enabled_feature_slugs: ["hot_sheet"]) }
      let!(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: organization, is_on: true) }
      let(:current_user) { FactoryBot.create(:organization_member, organization: organization) }
      let(:membership) { current_user.memberships.first }
      it "updates hotsheet" do
        expect(membership.notification_never?).to be_truthy
        # Doesn't include the parameter because when false, it doesn't include
        patch base_url, params: {
          id: current_user.username,
          hot_sheet_organization_ids: organization.id.to_s,
          hot_sheet_notifications: {organization.id.to_s => "1"}
        }, headers: {"HTTP_REFERER" => organization_hot_sheet_path(organization_id: organization.to_param)}
        expect(flash[:success]).to be_present
        expect(response).to redirect_to organization_hot_sheet_path(organization_id: organization.to_param)
        membership.reload
        expect(membership.notification_daily?).to be_truthy
      end
      context "with other parameters too" do
        let(:hot_sheet_configuration2) { FactoryBot.create(:hot_sheet_configuration, is_on: true) }
        let(:organization2) { hot_sheet_configuration2.organization }
        let!(:membership2) { FactoryBot.create(:membership_claimed, organization: organization2, user: current_user, hot_sheet_notification: "notification_daily") }
        it "updates all the parameters" do
          expect(membership.notification_never?).to be_truthy
          expect(membership2.notification_daily?).to be_truthy
          put base_url, params: {
            id: current_user.username,
            hot_sheet_organization_ids: "#{organization.id},#{organization2.id}",
            hot_sheet_notifications: {organization.id.to_s => "1"},
            user: {
              notification_newsletters: "true",
              notification_unstolen: "false"
            }
          }
          expect(flash[:success]).to be_present
          expect(response).to redirect_to edit_my_account_url
          membership.reload
          membership2.reload
          expect(membership.notification_daily?).to be_truthy
          expect(membership2.notification_daily?).to be_falsey

          current_user.reload
          expect(current_user.notification_newsletters).to be_truthy
          expect(current_user.notification_unstolen).to be_falsey
        end
      end
    end

    context "user_registration_organization" do
      let(:organization1) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: feature_slugs) }
      let!(:user_registration_organization1) { FactoryBot.create(:user_registration_organization, organization: organization1, user: current_user) }
      let(:bike1) { FactoryBot.create(:bike_organized, :with_ownership_claimed, user: current_user, creation_organization: organization1) }
      let(:bike2) { FactoryBot.create(:bike, :with_ownership_claimed, user: current_user) }
      let(:feature_slugs) { OrganizationFeature::REG_FIELDS }
      it "updates" do
        expect(user_registration_organization1.reload.all_bikes?).to be_truthy
        expect(user_registration_organization1.can_edit_claimed).to be_truthy
        expect(user_registration_organization1.registration_info).to be_blank

        expect(bike1.reload.bike_organizations.pluck(:organization_id)).to eq([organization1.id])
        bike_organization1 = bike1.bike_organizations.first
        expect(bike_organization1.reload.can_not_edit_claimed).to be_falsey
        expect(bike_organization1.overridden_by_user_registration?).to be_truthy
        expect(bike1.registration_info).to be_blank

        expect(bike2.reload.bike_organizations.pluck(:organization_id)).to eq([])
        expect(bike2.registration_info).to be_blank

        Sidekiq::Worker.clear_all
        put base_url, params: {
          edit_template: "registration_organizations",
          user_registration_organization_all_bikes: [user_registration_organization1.id.to_s, ""],
          user_registration_organization_can_edit_claimed: [],
          "reg_field-organization_affiliation_#{user_registration_organization1.organization_id}"=>"student",
          "reg_field-student_id_#{user_registration_organization1.organization_id}"=>"XXX777YYY"
        }
        # expect(AfterUserChangeWorker.jobs.count).to eq 1
        # expect(Sidekiq::Worker.jobs.count).to eq 1 # And it's the only job to have been enqueued!
        expect(flash[:success]).to be_present
        expect(response).to redirect_to edit_my_account_url(edit_template: "registration_organizations")
        expect(user_registration_organization1.reload.all_bikes?).to be_truthy
        expect(user_registration_organization1.can_edit_claimed).to be_falsey
        # target_info = {"organization_affiliation_#{}": "student", student_id: "XXX777YYY"}.as_json
        expect(user_registration_organization1.registration_info).to eq target_info

        Sidekiq::Testing.inline! {
          AfterUserChangeWorker.drain
        }
        expect(bike1.reload.bike_organizations.pluck(:organization_id)).to eq([organization1.id])
        expect(bike_organization1.reload.can_not_edit_claimed).to be_truthy
        expect(bike_organization1.overridden_by_user_registration?).to be_truthy
        expect(bike1.registration_info).to eq target_info

        expect(bike2.reload.bike_organizations.pluck(:organization_id)).to eq([organization1.id])
        bike_organization2 = bike2.bike_organizations.first
        expect(bike_organization2.can_edit_claimed).to be_truthy
        expect(bike_organization2.overridden_by_user_registration?).to be_truthy
        expect(bike2.registration_info).to eq target_info
      end
      # context "with multiple user_registration_organizations" do
      #   let!(:user_registration_organization2) { FactoryBot.create(:user_registration_organization, user: current_user) }
      #   let(:organization2) { user_registration_organization2.organization }
      #   it "updates" do

      #     # Remove the fancy user_registration_organization from all
      #   end
      # end
    end

    describe "preferred_language" do
      it "updates if valid" do
        expect(current_user.reload.preferred_language).to eq(nil)
        patch base_url, params: {id: current_user.username, locale: "nl", user: {preferred_language: "en"}}
        expect(flash[:success]).to match(/succesvol/i)
        expect(response).to redirect_to "/my_account/edit?locale=nl"
        expect(current_user.reload.preferred_language).to eq("en")
      end

      it "changes from previous if valid" do
        current_user.update_attribute :preferred_language, "en"
        patch base_url, params: {id: current_user.username, locale: "en", user: {preferred_language: "nl"}}
        expect(flash[:success]).to match(/successfully updated/i)
        expect(response).to redirect_to "/my_account/edit?locale=en"
        expect(current_user.reload.preferred_language).to eq("nl")
      end

      it "does not update the preferred_language if invalid" do
        expect(current_user.reload.preferred_language).to eq(nil)
        patch base_url, params: {id: current_user.username, user: {preferred_language: "klingon"}}
        expect(flash[:success]).to be_blank
        expect(response).to render_template(:edit)
        expect(current_user.reload.preferred_language).to eq(nil)
      end
    end
  end
end
