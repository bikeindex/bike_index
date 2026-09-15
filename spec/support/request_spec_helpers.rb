# Spec helpers that are included in all request specs
# via Rspec.configure (rails_helper)
module RequestSpecHelpers
  # Lame copy of user_root_url - required because of subdomain: false
  def user_root_url
    return my_account_url if current_user&.confirmed?

    root_url
  end

  # Captures the ViewComponent classes rendered during the given block,
  # via the !render.view_component ActiveSupport notification.
  def rendered_view_component_names(&block)
    names = []
    callback = ->(_, _, _, _, payload) { names << payload[:name] if payload[:name] }
    ActiveSupport::Notifications.subscribed(callback, "render.view_component", &block)
    names
  end

  # Rack::Test's cookie jar can't read a signed cookie, so rebuild a real one over it
  def signed_auth_cookie
    ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
      .signed[ControllerHelpers::AUTH_COOKIE_KEY]
  end

  def log_in(current_user = nil)
    return if current_user == false # Allow skipping log in by setting current_user: false

    current_user ||= FactoryBot.create(:user_confirmed)
    allow(User).to receive(:from_auth) { current_user }
  end

  # log_in's stub answers User.unconfirmed too, and skip_if_signed_in asks that before it asks
  # whether the user is confirmed - so anything reaching it has to sign in for real
  RSpec.shared_context :request_spec_signed_in_for_real do
    let(:user) { FactoryBot.create(:user_confirmed) }
    before { post "/session", params: {session: {email: user.email, password: user.password}} }
  end

  RSpec.shared_context :request_spec_logged_in_as_user do
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    before { log_in(current_user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_user_if_present do
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    before { log_in(current_user) if current_user.present? }
  end

  RSpec.shared_context :request_spec_logged_in_as_superuser do
    let(:current_user) { FactoryBot.create(:superuser) }
    before { log_in(current_user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_developer do
    let(:current_user) { FactoryBot.create(:developer) }
    before { log_in(current_user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_organization_admin do
    let(:current_organization) { FactoryBot.create(:organization) }
    let(:current_user) { FactoryBot.create(:organization_admin, organization: current_organization) }
    before { log_in(current_user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_organization_user do
    let(:current_organization) { FactoryBot.create(:organization) }
    let(:current_user) { FactoryBot.create(:organization_user, organization: current_organization) }
    before { log_in(current_user) }
  end

  RSpec.shared_context :request_spec_logged_in_as_ambassador do
    let(:current_organization) { FactoryBot.create(:organization_ambassador) }
    let(:current_user) { FactoryBot.create(:ambassador, organization: current_organization) }
    before { log_in(current_user) }
  end

  RSpec.shared_context :test_csrf_token do
    before { ActionController::Base.allow_forgery_protection = true }
    after { ActionController::Base.allow_forgery_protection = false }
  end

  # A token for the admin Doorkeeper app, which the admin token endpoints require
  RSpec.shared_context :admin_doorkeeper_token do
    let(:doorkeeper_app) { FactoryBot.create(:doorkeeper_app) }
    let(:token_user) { FactoryBot.create(:user_confirmed) }
    let(:doorkeeper_token) do
      Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: token_user.id)
    end
    let(:token_param) { {access_token: doorkeeper_token.token} }
    before { stub_const("API::TokenAuthenticatable::ADMIN_DOORKEEPER_APP_ID", doorkeeper_app.id) }
  end

  RSpec.shared_context :existing_doorkeeper_app do
    # The id sequence eventually reaches the real partner ids, which would make this app a partner
    before { stub_const("ControllerHelpers::PARTNER_DOORKEEPER_APP_IDS", partner_doorkeeper_app_ids) }
    let(:partner_doorkeeper_app_ids) { [] }
    let(:doorkeeper_app) { FactoryBot.create(:doorkeeper_app, owner: application_owner) }
    let(:application_owner) { FactoryBot.create(:user_confirmed) }
    let(:user) { application_owner } # So we don't waste time creating extra users
    let(:v2_access_id) { ENV["V2_ACCESSOR_ID"] = user.id.to_s }
    let(:token) { Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: user.id) }
    let(:all_scopes) { OAUTH_SCOPES.join(" ") }
    # The partner app, which valid_partner_domain looks up by id
    let(:bikehub_doorkeeper_app) do
      doorkeeper_app.update(redirect_uri: "https://parkit.bikehub.com/users/auth/bike_index/callback\r\nhttps://staging.bikehub.com/users/auth/bike_index/callback\r\n")
      doorkeeper_app
    end

    # Arriving through the partner's OAuth link is what puts partner/company into the session
    def arrive_via_partner(app: doorkeeper_app, **params)
      get "/oauth/authorize", params: {client_id: app.uid, response_type: "code",
                                       scope: "read_bikes", partner: "bikehub"}.merge(params)
    end

    let(:v2_access_token) do
      Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: v2_access_id, scopes: "write_bikes")
    end

    def create_doorkeeper_token(opts = {})
      Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: user.id, scopes: opts && opts[:scopes])
    end
  end
end
