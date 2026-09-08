require "rails_helper"

RSpec.describe Admin::UserRegistrationOrganizationsController, type: :request do
  base_url = "/admin/user_registration_organizations"

  context "given a logged-in superuser" do
    include_context :request_spec_logged_in_as_superuser

    describe "index" do
      it "responds with 200 OK and renders the index template" do
        get base_url
        expect(response).to be_ok
        expect(response).to render_template(:index)
      end

      context "with a user_registration_organization" do
        let(:user) { FactoryBot.create(:user) }
        let!(:user_registration_organization) do
          FactoryBot.create(:user_registration_organization, user:,
            registration_info: {"user_name" => "Alice Ambassador"})
        end

        it "renders the user and its registration info" do
          get "#{base_url}?period=all"

          expect(response).to be_ok
          expect(response.body).to match(%r{/admin/users/#{user.id}})
          expect(response.body).to match(/#{user.email}/)
          expect(response.body).to match(/Alice Ambassador/)
        end

        context "with the user deleted" do
          before { user.really_destroy! }

          it "marks the user missing rather than erroring on its bike count" do
            get "#{base_url}?period=all"

            expect(response).to be_ok
            expect(response.body).to match(/Missing user/)
          end
        end
      end
    end
  end
end
