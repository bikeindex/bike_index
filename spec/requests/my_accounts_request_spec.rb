require "rails_helper"

RSpec.describe MyAccountsController, type: :request do
  base_url = "/my_account"

  describe "show" do
    context "user not logged in" do
      it "redirects" do
        get base_url
        expect(response).to redirect_to(/session\/new/) # weird subdomain issue matching url directly otherwise
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
            expect(html_response).to match(/<title>You on Bike Index</)
            # This is pulled from the translations file
            expect(html_response).to match(/<meta.*Your bikes on Bike Index/)
          end
        end
        context "with organization" do
          let(:organization) { FactoryBot.create(:organization) }
          let(:current_user) { FactoryBot.create(:organization_user, organization: organization) }
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
            Sidekiq::Job.clear_all
            expect {
              get base_url
              expect(response).to be_ok
              expect(assigns(:show_general_alert)).to be_falsey
              expect(response).to render_template("show")
            }.to change(::Callbacks::AfterUserChangeJob.jobs, :count).by 0
          end
          context "with phone_verification enabled" do
            before { Flipper.enable(:phone_verification) }
            it "renders with show_general_alert" do
              Sidekiq::Job.clear_all
              expect {
                get base_url
                expect(response).to be_ok
                expect(assigns(:show_general_alert)).to be_truthy
                expect(response).to render_template("show")
              }.to change(::Callbacks::AfterUserChangeJob.jobs, :count).by 1
              ::Callbacks::AfterUserChangeJob.drain
              expect(current_user.reload.alert_slugs).to eq([])
            end
          end
        end
      end
    end
  end

  describe "/edit" do
    include_context :request_spec_logged_in_as_user
    let(:default_edit_templates) do
      {
        delete_account: "Delete account",
        root: "User Settings",
        password: "Password",
        sharing: "Sharing + Personal Page",
        membership: "Membership"
      }
    end
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
    # force skip_update to be false, like it is in reality (unblocks updating)
    before { current_user.skip_update = false }

    context "nil username" do
      it "doesn't update username" do
        current_user.reload
        expect(current_user.username).to eq "something"
        expect {
          patch base_url, params: {id: current_user.username, user: {username: " ", name: "tim"}, edit_template: "sharing"}
        }.to change(::Callbacks::AfterUserChangeJob.jobs, :size).by(1)
        expect(assigns(:edit_template)).to eq("sharing")
        current_user.reload
        expect(current_user.username).to eq("something")
      end
    end

    it "updates notification" do
      expect(current_user.notification_unstolen).to be_truthy # Because it's set to true by default
      expect {
        patch base_url, params: {id: current_user.username, user: {notification_newsletters: "1", notification_unstolen: "0"}}
      }.to change(::Callbacks::AfterUserChangeJob.jobs, :size).by(1)
      expect(response).to redirect_to edit_my_account_url(edit_template: "root")
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
      let!(:state) { FactoryBot.create(:state_new_york) }
      let(:user_address_params) do
        {
          id: current_user.username,
          user: {
            name: "Mr. Slick",
            address_record_attributes:,
            notification_newsletters: "1",
            phone: "3223232"
          }
        }
      end
      let(:address_record_attributes) do
        {
          country_id: country.id,
          region_record_id: state.id,
          region_string: "something",
          city: "New York",
          street: "278 Broadway",
          postal_code: "10007"
        }
      end
      let(:target_address_record_attrs) do
        {
          user_id: current_user.id,
          country_id: country.id,
          region_record_id: state.id,
          street: "278 Broadway",
          postal_code: "10007",
          latitude: default_location[:latitude],
          longitude: default_location[:longitude]
        }
      end
      def expect_updated_user_and_address(user, address_record)
        user.reload
        expect(user.name).to eq("Mr. Slick")
        expect(user.notification_newsletters).to be_truthy
        expect(user.phone).to eq "3223232"
        expect(user.address_set_manually).to be_truthy

        expect(address_record).to match_hash_indifferently target_address_record_attrs

        expect(user.address_record_id).to eq address_record.id
        expect(user.latitude).to eq default_location[:latitude]
        expect(user.longitude).to eq default_location[:longitude]
      end
      it "sets address, geocodes" do
        current_user.reload
        expect(current_user.address_set_manually).to be_falsey
        expect(current_user.notification_newsletters).to be_falsey
        put base_url, params: user_address_params
        expect(response).to redirect_to "/my_account/edit/root"
        expect(flash[:error]).to_not be_present
        Callbacks::AddressRecordUpdateAssociationsJob.drain

        expect_updated_user_and_address(current_user, AddressRecord.last)

        expect(AddressRecord.count).to eq 1
      end
      context "existing address_record" do
        let!(:address_record) { FactoryBot.create(:address_record, user: current_user, kind: :user) }
        let(:address_record_attributes) do
          {
            country_id: country.id,
            region_record_id: "",
            region_string: "",
            city: " ",
            street: " ",
            postal_code: "10007",
            id: address_record.id.to_s
          }
        end

        it "does not create a new address record" do
          current_user.reload
          expect(current_user.address_set_manually).to be_falsey
          expect(current_user.notification_newsletters).to be_falsey
          expect(AddressRecord.count).to eq 1
          Sidekiq::Job.clear_all
          Sidekiq::Testing.inline! do
            put base_url, params: user_address_params
            expect(response).to redirect_to "/my_account/edit/root"
          end
          expect(flash[:error]).to_not be_present
          expect(AddressRecord.count).to eq 1
          expect_updated_user_and_address(current_user, address_record.reload)
        end
        context "passed ID that isn't user's address_record_id" do
          let!(:address_record) { FactoryBot.create(:address_record, user: FactoryBot.create(:user)) }

          it "creates a new address_record" do
            current_user.reload
            expect(current_user.address_set_manually).to be_falsey
            expect(current_user.notification_newsletters).to be_falsey
            expect(AddressRecord.count).to eq 1
            Sidekiq::Job.clear_all
            Sidekiq::Testing.inline! do
              put base_url, params: user_address_params
              expect(response).to redirect_to "/my_account/edit/root"
            end
            expect(flash[:error]).to_not be_present
            expect_updated_user_and_address(current_user, AddressRecord.last)

            expect(AddressRecord.count).to eq 2
            # Verify that the original address_record is unchanged
            expect(address_record.reload.street).to eq "One Shields Ave"
          end
        end
      end
    end

    describe "settings sharing links (twitter, instagram, website)" do
      it "updates sharing links on the User" do
        current_user.update(
          show_twitter: false,
          twitter: nil,
          show_instagram: false,
          instagram: nil,
          show_website: false
        )

        patch base_url, params: {id: current_user.id,
                                 user: {
                                   instagram: "bikeinsta", show_instagram: true,
                                   twitter: "biketwitter", show_twitter: true,
                                   my_bikes_link_target: "https://bikeindex.org", show_website: true
                                 }}

        current_user.reload
        expect(current_user.instagram).to eq "bikeinsta"
        expect(current_user.show_instagram).to be true
        expect(current_user.twitter).to eq "biketwitter"
        expect(current_user.show_twitter).to be true
        expect(current_user.mb_link_target).to eq "https://bikeindex.org"
        expect(current_user.show_website).to be true
      end
    end

    describe "updating phone" do
      it "updates and adds the phone" do
        current_user.reload
        expect(current_user.phone).to be_blank
        expect(current_user.user_phones.count).to eq 0
        Sidekiq::Job.clear_all
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
        expect(user_phone.notifications.count).to eq 0
      end
      context "with phone_verification" do
        before { Flipper.enable(:phone_verification) }
        it "updates and adds the phone" do
          current_user.reload
          expect(current_user.phone).to be_blank
          expect(current_user.user_phones.count).to eq 0
          Sidekiq::Job.clear_all
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
        expect(response).to redirect_to "/my_account/edit/root"
        expect(flash[:success]).to be_present
        current_user.reload
        expect(current_user.reload.authenticate("172ddfasdf1LDF")).to be_truthy
      end
    end

    context "organization with hotsheet" do
      let(:organization) { FactoryBot.create(:organization_with_organization_features, :in_nyc, enabled_feature_slugs: ["hot_sheet"]) }
      let!(:hot_sheet_configuration) { FactoryBot.create(:hot_sheet_configuration, organization: organization, is_on: true) }
      let(:current_user) { FactoryBot.create(:organization_user, organization: organization) }
      let(:organization_role) { current_user.organization_roles.first }
      it "updates hotsheet" do
        expect(organization_role.notification_never?).to be_truthy
        # Doesn't include the parameter because when false, it doesn't include
        patch base_url, params: {
          id: current_user.username,
          hot_sheet_organization_ids: organization.id.to_s,
          hot_sheet_notifications: {organization.id.to_s => "1"}
        }, headers: {"HTTP_REFERER" => organization_hot_sheet_path(organization_id: organization.to_param)}
        expect(flash[:success]).to be_present
        expect(response).to redirect_to organization_hot_sheet_path(organization_id: organization.to_param)
        organization_role.reload
        expect(organization_role.notification_daily?).to be_truthy
      end
      context "with other parameters too" do
        let(:hot_sheet_configuration2) { FactoryBot.create(:hot_sheet_configuration, is_on: true) }
        let(:organization2) { hot_sheet_configuration2.organization }
        let!(:organization_role2) { FactoryBot.create(:organization_role_claimed, organization: organization2, user: current_user, hot_sheet_notification: "notification_daily") }
        it "updates all the parameters" do
          expect(organization_role.notification_never?).to be_truthy
          expect(organization_role2.notification_daily?).to be_truthy
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
          expect(response).to redirect_to edit_my_account_url(edit_template: "root")
          organization_role.reload
          organization_role2.reload
          expect(organization_role.notification_daily?).to be_truthy
          expect(organization_role2.notification_daily?).to be_falsey

          current_user.reload
          expect(current_user.notification_newsletters).to be_truthy
          expect(current_user.notification_unstolen).to be_falsey
        end
      end
    end

    context "user_registration_organization" do
      let(:organization1) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: feature_slugs) }
      let!(:user_registration_organization1) { FactoryBot.create(:user_registration_organization, all_bikes: false, organization: organization1, user: current_user) }
      let(:bike1) { FactoryBot.create(:bike_organized, :with_ownership_claimed, user: current_user, creation_organization: organization1) }
      let(:bike_organization1) { bike1.bike_organizations.first }
      let(:feature_slugs) { OrganizationFeature::REG_FIELDS }
      let(:update_params) do
        {
          :edit_template => "registration_organizations",
          :user_registration_organization_all_bikes => [user_registration_organization1.id.to_s, ""],
          :user_registration_organization_can_edit_claimed => [],
          "reg_field-organization_affiliation_#{organization1.id}" => "student",
          "reg_field-student_id_#{organization1.id}" => "XXX777YYY"
        }
      end
      let(:target_info) do
        {"organization_affiliation_#{organization1.id}" => "student",
         "student_id_#{organization1.id}" => "XXX777YYY"}.as_json
      end
      def expect_bike1_initiated
        expect(user_registration_organization1.reload.all_bikes?).to be_falsey
        expect(user_registration_organization1.can_edit_claimed).to be_truthy
        expect(user_registration_organization1.registration_info).to be_blank
        expect(bike1.reload.bike_organizations.pluck(:organization_id)).to eq([organization1.id])
        expect(bike_organization1.reload.can_edit_claimed).to be_truthy
        expect(bike_organization1.overridden_by_user_registration?).to be_falsey
        expect(bike1.registration_info).to be_blank
      end

      it "updates" do
        expect_bike1_initiated

        Sidekiq::Job.clear_all
        put base_url, params: update_params
        expect(::Callbacks::AfterUserChangeJob.jobs.count).to eq 1
        expect(Sidekiq::Job.jobs.count).to eq 1 # And it's the only job to have been enqueued!
        expect(flash[:success]).to be_present
        expect(response).to redirect_to edit_my_account_url(edit_template: "registration_organizations")
        expect(user_registration_organization1.reload.all_bikes?).to be_truthy
        expect(user_registration_organization1.can_edit_claimed).to be_falsey
        expect(user_registration_organization1.registration_info).to eq target_info

        Sidekiq::Testing.inline! {
          ::Callbacks::AfterUserChangeJob.drain
        }
        expect(bike1.reload.bike_organizations.pluck(:organization_id)).to eq([organization1.id])
        expect(bike1.registration_info).to eq target_info
        expect(bike_organization1.reload.can_edit_claimed).to be_falsey
        expect(bike_organization1.overridden_by_user_registration?).to be_truthy
      end
      context "multiple bikes" do
        let(:bike2) { FactoryBot.create(:bike, :with_ownership_claimed, user: current_user) }
        let(:bike2_organization1) { bike2.bike_organizations.where(organization_id: organization1.id).first }
        it "updates" do
          expect_bike1_initiated

          expect(bike2.reload.bike_organizations.pluck(:organization_id)).to eq([])
          expect(bike2.registration_info).to be_blank

          Sidekiq::Job.clear_all
          put base_url, params: {
            :edit_template => "registration_organizations",
            :user_registration_organization_all_bikes => [user_registration_organization1.id.to_s, ""],
            :user_registration_organization_can_edit_claimed => [""],
            "reg_field-organization_affiliation_#{organization1.id}" => "student",
            "reg_field-student_id_#{organization1.id}" => "XXX777YYY"
          }
          expect(::Callbacks::AfterUserChangeJob.jobs.count).to eq 1
          expect(Sidekiq::Job.jobs.count).to eq 1 # And it's the only job to have been enqueued!
          expect(flash[:success]).to be_present
          expect(response).to redirect_to edit_my_account_url(edit_template: "registration_organizations")
          expect(user_registration_organization1.reload.all_bikes?).to be_truthy
          expect(user_registration_organization1.can_edit_claimed).to be_falsey
          expect(user_registration_organization1.registration_info).to eq target_info

          Sidekiq::Testing.inline! {
            ::Callbacks::AfterUserChangeJob.drain
          }
          expect(bike1.reload.bike_organizations.pluck(:organization_id)).to eq([organization1.id])
          expect(bike1.registration_info).to eq target_info
          expect(bike_organization1.reload.can_edit_claimed).to be_falsey
          expect(bike_organization1.overridden_by_user_registration?).to be_truthy

          expect(bike2.reload.bike_organizations.pluck(:organization_id)).to eq([organization1.id])
          expect(bike2.registration_info).to eq target_info
          expect(bike2_organization1.can_edit_claimed).to be_falsey
          expect(bike2_organization1.overridden_by_user_registration?).to be_truthy
        end
        context "with multiple user_registration_organizations" do
          let(:organization2) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["reg_organization_affiliation"]) }
          let(:user_registration_organization2) { FactoryBot.create(:user_registration_organization, all_bikes: true, user: current_user, organization: organization2) }
          let(:bike3_information) { {bike_sticker: "vvvv"}.merge(default_location_registration_address).as_json }
          let(:bike3) { FactoryBot.create(:bike, :with_ownership_claimed, :with_address_record, address_in: :new_york, user: current_user, creation_registration_info: bike3_information) }
          let(:target_extra_info) do
            target_info.merge("organization_affiliation_#{organization2.id}" => "employee")
              .merge(default_location_registration_address).as_json
          end
          it "updates" do
            expect_bike1_initiated
            expect(current_user.reload.to_coordinates).to eq([nil, nil])
            expect(current_user.address_set_manually).to be_falsey
            expect(bike2.bike_organizations.pluck(:organization_id)).to eq([])

            expect(user_registration_organization2.registration_info).to be_blank

            expect(bike2.reload.bike_organizations.pluck(:organization_id)).to eq([organization2.id])
            expect(bike2.registration_info).to be_blank
            bike2_organization2 = bike2.bike_organizations.where(organization_id: organization2.id).first
            expect(bike2_organization2).to be_present
            bike1_organization2 = bike1.bike_organizations.where(organization_id: organization2.id).first
            expect(bike1_organization2).to be_valid
            bike1_organization2.destroy

            expect(bike3.reload.registration_info).to eq(bike3_information)
            expect(bike3.address_hash_legacy).to eq default_location_registration_address.merge(country: "United States").as_json

            Sidekiq::Job.clear_all
            put base_url, params: {
              :edit_template => "registration_organizations",
              :user_registration_organization_all_bikes => [user_registration_organization1.id.to_s, ""],
              :user_registration_organization_can_edit_claimed => ["", user_registration_organization2.id],
              "reg_field-organization_affiliation_#{organization1.id}" => "student",
              "reg_field-student_id_#{organization1.id}" => "XXX777YYY",
              "reg_field-organization_affiliation_#{organization2.id}" => "employee"
            }
            expect(::Callbacks::AfterUserChangeJob.jobs.count).to eq 1
            expect(Sidekiq::Job.jobs.count).to eq 1 # And it's the only job to have been enqueued!
            expect(flash[:success]).to be_present
            expect(response).to redirect_to edit_my_account_url(edit_template: "registration_organizations")
            expect(user_registration_organization1.reload.all_bikes?).to be_truthy
            expect(user_registration_organization1.can_edit_claimed).to be_falsey
            expect(user_registration_organization1.registration_info).to eq target_extra_info

            expect(user_registration_organization2.reload.all_bikes?).to be_falsey
            expect(user_registration_organization2.can_edit_claimed).to be_truthy
            expect(user_registration_organization2.registration_info).to eq target_extra_info

            Sidekiq::Testing.inline! {
              ::Callbacks::AfterUserChangeJob.drain
            }
            deleted_bike_organization = BikeOrganization.unscoped.where(id: bike1_organization2.id).first
            expect(deleted_bike_organization.deleted?).to be_truthy
            # expect(BikeOrganization.unscoped.where(id: bike1_organization2.id).deleted?).to be_truthy
            expect(bike1.reload.organizations.pluck(:id)).to eq([organization1.id])
            expect(bike1.registration_info).to eq target_extra_info
            expect(bike_organization1.reload.can_edit_claimed).to be_falsey
            expect(bike_organization1.overridden_by_user_registration?).to be_truthy

            expect(bike2.reload.bike_organizations.pluck(:organization_id)).to match_array([organization1.id, organization2.id])
            expect(bike2.registration_info).to eq target_extra_info.merge(default_location_registration_address).as_json
            expect(bike2_organization1.can_edit_claimed).to be_falsey
            expect(bike2_organization1.overridden_by_user_registration?).to be_truthy

            expect(bike3.reload.organizations.pluck(:id)).to match_array([organization1.id])
            target_bike3_info = bike3_information.merge(target_extra_info).merge(default_location_registration_address).as_json
            expect(bike3.registration_info).to eq target_bike3_info

            expect(current_user.reload.address_record).to match_hash_indifferently default_location_address_record_attrs.merge(kind: "user")

            expect(current_user.address_hash_legacy)
              .to eq default_location_registration_address.merge("country" => "United States")
          end
        end
      end
    end

    describe "preferred_language and time_single_format" do
      it "updates if valid" do
        expect(current_user.reload.preferred_language).to eq(nil)
        patch base_url, params: {id: current_user.username, locale: "nl", user: {preferred_language: "en", time_single_format: true}}
        expect(flash[:success]).to match(/succesvol/i)
        expect(response).to redirect_to "/my_account/edit/root?locale=nl"
        expect(current_user.reload.preferred_language).to eq("en")
        expect(current_user.time_single_format).to be_truthy
      end

      it "changes from previous if valid" do
        current_user.update_attribute :preferred_language, "en"
        patch base_url, params: {id: current_user.username, locale: "en", user: {preferred_language: "nl"}}
        expect(flash[:success]).to match(/successfully updated/i)
        expect(response).to redirect_to "/my_account/edit/root?locale=en"
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

  describe "delete" do
    let!(:current_user) { let!(:user) { FactoryBot.create(:user_confirmed, :with_organization, role: "member") } }
    let!(:bike) { FactoryBot.create(:bike, :with_ownership, user: current_user) }
    include_context :request_spec_logged_in_as_user

    it "deletes" do
      expect(current_user.reload.deletable?).to be_truthy
      expect do
        delete base_url
      end.to change(User, :count).by(-1)
      expect(Bike.count).to eq 0
      expect(response).to redirect_to(goodbye_url)
      expect(flash[:notice]).to be_present
    end

    context "organization admin" do
      let!(:current_user) { FactoryBot.create(:user, :with_organization, role: "admin") }

      it "does not delete" do
        expect(current_user.reload.deletable?).to be_falsey
        expect do
          delete base_url
        end.to change(User, :count).by(0)
        expect(Bike.count).to eq 1
        expect(flash[:error]).to eq "Organization admins cannot delete their accounts. Email support@bikeindex.org for help"
      end
    end
  end
end
