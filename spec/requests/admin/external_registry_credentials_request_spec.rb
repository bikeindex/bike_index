require "rails_helper"

RSpec.describe Admin::ExternalRegistryCredentialsController, type: :request do
  base_url = "/admin/external_registry_credentials"
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders, offering the reset only for a credential whose token can be reset" do
      resettable = FactoryBot.create(:project529_credential, access_token_expires_at: Time.current - 1.day)
      stop_heling = FactoryBot.create(:stop_heling_credential)

      get base_url
      expect(response).to be_ok
      expect(response).to render_template(:index)
      expect(response.body).to match(reset_admin_external_registry_credential_path(resettable))
      expect(response.body).to_not match(reset_admin_external_registry_credential_path(stop_heling))
    end
  end

  describe "create" do
    it "creates the credential of the chosen type" do
      expect {
        post base_url, params: {external_registry_credential: {type: "ExternalRegistryCredential::StopHelingCredential", app_id: "app", access_token: "token"}}
      }.to change(ExternalRegistryCredential, :count).by 1

      expect(ExternalRegistryCredential.last).to be_a(ExternalRegistryCredential::StopHelingCredential)
      expect(ExternalRegistryCredential.last).to have_attributes(app_id: "app", access_token: "token")
    end
  end

  describe "update" do
    it "updates, without changing the type" do
      credential = FactoryBot.create(:stop_heling_credential)

      patch "#{base_url}/#{credential.id}", params: {
        external_registry_credential: {app_id: "new app", type: "ExternalRegistryCredential::Project529Credential"}
      }

      expect(response).to redirect_to(admin_external_registry_credentials_url)
      expect(ExternalRegistryCredential.find(credential.id)).to be_a(ExternalRegistryCredential::StopHelingCredential)
      expect(credential.reload.app_id).to eq "new app"
    end
  end
end
