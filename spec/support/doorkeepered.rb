shared_context :existing_doorkeeper_app do
  let(:doorkeeper_app) { create_doorkeeper }

  def create_doorkeeper(_opts = {})
    @user = FactoryGirl.create(:confirmed_user)
    @application = Doorkeeper::Application.new(name: 'MyApp', redirect_uri: 'https://app.com')
    @application.owner = @user
    @application.save
    @application
  end

  def create_doorkeeper_app(opts = {})
    create_doorkeeper(opts)
    if opts[:with_v2_accessor]
      accessor_id = create_v2_access_id.to_i
      @accessor_token = Doorkeeper::AccessToken.create!(application_id: @application.id, resource_owner_id: accessor_id, scopes: 'write_bikes')
    end
    @token = Doorkeeper::AccessToken.create!(application_id: @application.id, resource_owner_id: @user.id, scopes: opts && opts[:scopes])
  end

  def create_v2_access_id
    ENV['V2_ACCESSOR_ID'] = FactoryGirl.create(:user).id.to_s
  end
end