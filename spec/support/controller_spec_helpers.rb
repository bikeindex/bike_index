# Spec helpers that are included in all controller specs
# via Rspec.configure (rails_helper)
module ControllerSpecHelpers
  def set_current_user(user)
    return unless user.present?

    cookies.signed[:auth] =
      {secure: true, httponly: true, value: [user.id, user.auth_token]}
  end

  RSpec.shared_context :logged_in_as_user do
    let(:user) { FactoryBot.create(:user_confirmed) }
    before { set_current_user(user) }
  end

  RSpec.shared_context :logged_in_as_superuser do
    let(:user) { FactoryBot.create(:superuser) }
    before { set_current_user(user) }
  end

  RSpec.shared_context :logged_in_as_organization_admin do
    let(:user) { FactoryBot.create(:organization_admin, organization: organization) }
    let(:organization) { FactoryBot.create(:organization) }
    before :each do
      set_current_user(user)
    end
  end

  RSpec.shared_context :logged_in_as_organization_user do
    let(:user) { FactoryBot.create(:organization_user, organization: organization) }
    let(:organization) { FactoryBot.create(:organization) }
    before :each do
      set_current_user(user)
    end
  end

  RSpec.shared_context :logged_in_as_ambassador do
    let(:user) { FactoryBot.create(:ambassador, organization: organization) }
    let(:organization) { FactoryBot.create(:organization_ambassador) }
    before { set_current_user(user) }
  end

  RSpec.shared_context :test_csrf_token do
    before { ActionController::Base.allow_forgery_protection = true }
    after { ActionController::Base.allow_forgery_protection = false }
  end

  RSpec.shared_context :existing_doorkeeper_app do
    let(:doorkeeper_app) { FactoryBot.create(:doorkeeper_app, owner: application_owner) }
    let(:application_owner) { FactoryBot.create(:user_confirmed) }
    let(:user) { application_owner } # So we don't waste time creating extra users
    let(:v2_access_id) { ENV["V2_ACCESSOR_ID"] = user.id.to_s }
    let(:token) { Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: user.id) }
    let(:all_scopes) { OAUTH_SCOPES.join(" ") }
    # Partner Doorkeeper app looked up by ID
    let(:bikehub_doorkeeper_app) do
      doorkeeper_app.update(id: 264,
        redirect_uri: "https://parkit.bikehub.com/users/auth/bike_index/callback\r\nhttps://staging.bikehub.com/users/auth/bike_index/callback\r\n")
      doorkeeper_app
    end

    let(:v2_access_token) do
      Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: v2_access_id, scopes: "write_bikes")
    end

    def create_doorkeeper_token(opts = {})
      Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: user.id, scopes: opts && opts[:scopes])
    end
  end
end
