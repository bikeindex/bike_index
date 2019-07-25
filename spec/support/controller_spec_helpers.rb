# Spec helpers that are included in all controller specs
# via Rspec.configure (rails_helper)
module ControllerSpecHelpers
  def set_current_user(user)
    cookies.signed[:auth] =
      { secure: true, httponly: true, value: [user.id, user.auth_token] }
  end

  RSpec.shared_context :logged_in_as_user do
    let(:user) { FactoryBot.create(:user_confirmed) }
    before { set_current_user(user) }
  end

  RSpec.shared_context :logged_in_as_super_admin do
    let(:user) { FactoryBot.create(:admin) }
    before { set_current_user(user) }
  end

  RSpec.shared_context :logged_in_as_organization_admin do
    let(:user) { FactoryBot.create(:organization_admin, organization: organization) }
    let(:organization) { FactoryBot.create(:organization) }
    before :each do
      set_current_user(user)
    end
  end

  RSpec.shared_context :logged_in_as_organization_member do
    let(:user) { FactoryBot.create(:organization_member, organization: organization) }
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
    let(:doorkeeper_app) { create_doorkeeper_app }
    let(:application_owner) { FactoryBot.create(:user_confirmed) }
    let(:user) { application_owner } # So we don't waste time creating extra users
    let(:v2_access_id) { ENV["V2_ACCESSOR_ID"] = user.id.to_s }
    let(:token) { Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: user.id) }
    let(:all_scopes) { OAUTH_SCOPES.join(" ") }

    let(:v2_access_token) do
      Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: v2_access_id, scopes: "write_bikes")
    end

    def create_doorkeeper_token(opts = {})
      Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: user.id, scopes: opts && opts[:scopes])
    end

    def create_doorkeeper_app(_opts = {})
      application = Doorkeeper::Application.new(name: "MyApp", redirect_uri: "https://app.com")
      application.owner = application_owner
      application.save
      application
    end
  end
end
