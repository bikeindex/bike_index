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
    context "no page given" do
      it "renders root" do
        get "#{base_url}/edit"
        expect(response).to be_ok
        expect(assigns(:edit_template)).to eq("root")
        expect(response).to render_template("edit")
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
            expect(response).to render_template(partial: "_#{template}")
            expect(response).to render_template("layouts/application")
          end
        end
      end
    end
  end

  describe "update" do
    include_context :request_spec_logged_in_as_user
    let!(:current_user) { FactoryBot.create(:user_confirmed, terms_of_service: false, password: "old_password", password_confirmation: "old_password", username: "something") }

    context "nil username" do
      it "doesn't update username" do
        current_user.reload
        expect(current_user.username).to eq "something"
        patch base_url, params: {id: current_user.username, user: {username: " ", name: "tim"}, edit_template: "sharing"}
        expect(assigns(:edit_template)).to eq("sharing")
        current_user.reload
        expect(current_user.username).to eq("something")
      end
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

    # context "setting address" do
    #   let(:country) { Country.united_states }
    #   let(:state) { FactoryBot.create(:state, name: "New York", abbreviation: "NY") }
    #   it "sets address, geocodes" do
    #     user.reload
    #     expect(user.address_set_manually).to be_falsey
    #     set_current_user(user)
    #     expect(user.notification_newsletters).to be_falsey
    #     put :update, params: {
    #       id: user.username,
    #       user: {
    #         name: "Mr. Slick",
    #         country_id: country.id,
    #         state_id: state.id,
    #         city: "New York",
    #         street: "278 Broadway",
    #         zipcode: "10007",
    #         notification_newsletters: "1",
    #         phone: "3223232"
    #       }
    #     }
    #     expect(response).to redirect_to(edit_my_account_url)
    #     expect(flash[:error]).to_not be_present
    #     user.reload
    #     expect(user.name).to eq("Mr. Slick")
    #     expect(user.country).to eq country
    #     expect(user.state).to eq state
    #     expect(user.street).to eq "278 Broadway"
    #     expect(user.zipcode).to eq "10007"
    #     expect(user.notification_newsletters).to be_truthy
    #     expect(user.latitude).to eq default_location[:latitude]
    #     expect(user.longitude).to eq default_location[:longitude]
    #     expect(user.phone).to eq "3223232"
    #     expect(user.address_set_manually).to be_truthy
    #   end
    # end

    # describe "updating phone" do
    #   it "updates and adds the phone" do
    #     user.reload
    #     expect(user.phone).to be_blank
    #     expect(user.user_phones.count).to eq 0
    #     set_current_user(user)
    #     Sidekiq::Worker.clear_all
    #     VCR.use_cassette("users_controller-update_phone", match_requests_on: [:path]) do
    #       Sidekiq::Testing.inline! {
    #         put :update, params: {id: user.id, user: {phone: "15005550006"}}
    #       }
    #     end
    #     expect(flash[:success]).to be_present
    #     user.reload
    #     expect(user.phone).to eq "15005550006"
    #     expect(user.user_phones.count).to eq 1
    #     expect(user.phone_waiting_confirmation?).to be_truthy
    #     expect(user.alert_slugs).to eq(["phone_waiting_confirmation"])

    #     user_phone = user.user_phones.reorder(:created_at).last
    #     expect(user_phone.phone).to eq "15005550006"
    #     expect(user_phone.confirmed?).to be_falsey
    #     expect(user_phone.confirmation_code).to be_present
    #     expect(user_phone.notifications.count).to eq 1
    #   end
    #   context "without background" do
    #     it "still shows general alert" do
    #       user.reload
    #       expect(user.phone).to be_blank
    #       expect(user.user_phones.count).to eq 0
    #       set_current_user(user)
    #       put :update, params: {id: user.id, user: {phone: "15005550006"}}
    #       expect(flash[:success]).to be_present
    #       user.reload
    #       expect(user.phone).to eq "15005550006"
    #       expect(user.user_phones.count).to eq 0
    #       expect(user.alert_slugs).to eq(["phone_waiting_confirmation"])
    #     end
    #   end
    # end
  end
end
