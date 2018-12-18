shared_context :existing_doorkeeper_app do
  let(:doorkeeper_app) { create_doorkeeper }
  let(:application_owner) { FactoryGirl.create(:confirmed_user) }
  let(:user) { application_owner } # So we don't waste time creating extra users
  let(:v2_access_id) { ENV["V2_ACCESSOR_ID"] = user.id.to_s }
  let(:token) { Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: user.id) }

  let(:v2_access_token) do
    Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: v2_access_id, scopes: "write_bikes")
  end

  def create_doorkeeper_token(opts = {})
    Doorkeeper::AccessToken.create!(application_id: doorkeeper_app.id, resource_owner_id: user.id, scopes: opts && opts[:scopes])
  end

  def create_doorkeeper(_opts = {})
    application = Doorkeeper::Application.new(name: "MyApp", redirect_uri: "https://app.com")
    application.owner = application_owner
    application.save
    application
  end

  def create_doorkeeper_app(opts = {})
    create_doorkeeper(opts)
  end
end
