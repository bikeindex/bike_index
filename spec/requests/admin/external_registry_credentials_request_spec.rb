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
end
