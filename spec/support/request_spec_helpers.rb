shared_context :logged_in_as_user do
  let(:user) { FactoryBot.create(:user_confirmed) }
  before { set_current_user(user) }
end

shared_context :logged_in_as_super_admin do
  let(:user) { FactoryBot.create(:admin) }
  before { set_current_user(user) }
end

shared_context :logged_in_as_organization_admin do
  let(:user) { FactoryBot.create(:organization_admin) }
  let(:organization) { user.organizations.first }
  before :each do
    set_current_user(user)
  end
end

shared_context :logged_in_as_organization_member do
  let(:user) { FactoryBot.create(:organization_member) }
  let(:organization) { user.organizations.first }
  before :each do
    set_current_user(user)
  end
end

shared_context :logged_in_as_ambassador do
  let(:user) { FactoryBot.create(:user_ambassador) }
  before { set_current_user(user) }
end

shared_context :test_csrf_token do
  before { ActionController::Base.allow_forgery_protection = true }
  after { ActionController::Base.allow_forgery_protection = false }
end

shared_context :existing_doorkeeper_app do
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

# Request spec helpers that are included in all request specs via Rspec.configure (rails_helper)
module RequestSpecHelpers
  def json_headers
    { "CONTENT_TYPE" => "application/json", "ACCEPT" => "application/json" }
  end

  def json_result
    r = JSON.parse(response.body)
    r.is_a?(Hash) ? r.with_indifferent_access : r
  end
end
