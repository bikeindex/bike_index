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
          let(:ownership) { FactoryBot.create(:ownership, user_id: current_user.id, current: true) }
          let(:bike) { ownership.bike }
          let(:bike_2) { FactoryBot.create(:bike) }
          let(:lock) { FactoryBot.create(:lock, user: current_user) }
          before do
            allow_any_instance_of(User).to receive(:bikes) { [bike, bike_2] }
            allow_any_instance_of(User).to receive(:locks) { [lock] }
          end
          it "renders and user things are assigned" do
            get base_url, params: { per_page: 1 }
            expect(response.status).to eq(200)
            expect(response).to render_template("show")
            expect(assigns(:bikes).count).to eq 1
            expect(assigns(:per_page).to_s).to eq "1"
            expect(assigns(:bikes).first).to eq(bike)
            expect(assigns(:locks).first).to eq(lock)
          end
        end
        context "with show_general_alert" do
          before { current_user.update_column :general_alerts, ["has_stolen_bikes_without_locations"] }
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
end
