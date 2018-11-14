require 'spec_helper'

describe 'Me API V3' do
  describe 'unauthorized current' do
    it 'Sends correct error code when no user present' do
      get '/api/v3/me'
      expect(response.response_code).to eq(401)
      expect(response.body.match('OAuth')).to be_present
      expect(response.headers['Content-Type'].match('json')).to be_present
      expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
      expect(response.headers['Access-Control-Request-Method']).to eq('*')
    end
  end

  describe 'authorized current' do
    before :each do
      create_doorkeeper_app
    end
    context 'fully scoped token' do
      before { @token.update_attribute :scopes, OAUTH_SCOPES_S }
      it 'responds with all available attributes with full scoped token' do
        get '/api/v3/me', format: :json, access_token: @token.token
        result = JSON.parse(response.body)
        expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
        expect(result['user']['name']).to eq(@user.name)
        expect(result['id']).to eq(@user.id.to_s)
        expect(result['user'].is_a?(Hash)).to be_truthy
        expect(result['bike_ids'].is_a?(Array)).to be_truthy
        expect(result['memberships'].is_a?(Array)).to be_truthy
        expect(response.response_code).to eq(200)
      end
    end

    context 'no bikes scoped' do
      let(:token) { Doorkeeper::AccessToken.create!(application_id: @application.id, resource_owner_id: @user.id) }
      it "doesn't include bikes" do
        expect(token.scopes.to_s.match('read_bikes').present?).to be_falsey
        get '/api/v3/me', format: :json, access_token: token.token
        expect(response.response_code).to eq(200)
        result = JSON.parse(response.body)
        expect(result['id']).to eq(@user.id.to_s)
        expect(result['bike_ids'].present?).to be_falsey
      end
    end

    context 'no membership scoped' do
      let(:token) { Doorkeeper::AccessToken.create!(application_id: @application.id, resource_owner_id: @user.id) }
      it "doesn't include memberships if no memberships scoped" do
        expect(token.scopes.to_s.match('read_organization_membership').present?).to be_falsey
        get '/api/v3/me', format: :json, access_token: token.token
        expect(response.response_code).to eq(200)
        result = JSON.parse(response.body)
        expect(result['id']).to eq(@user.id.to_s)
        expect(result['memberships'].present?).to be_falsey
      end
    end

    context 'Default scope' do
      it "doesn't include memberships (or is_admin)" do
        get '/api/v3/me', format: :json, access_token: @token.token
        expect(response.response_code).to eq(200)
        result = JSON.parse(response.body)
        expect(result['id']).to eq(@user.id.to_s)
        expect(result['user'].present?).to be_falsey
      end
    end
  end

  describe 'current/bikes' do
    before :each do
      create_doorkeeper_app
    end
    it "works if it's authorized" do
      @token.update_attribute :scopes, 'read_bikes'
      get '/api/v3/me/bikes', format: :json, access_token: @token.token
      # get '/api/v3/me/bikes', {}, 'Authorization' => "Basic #{Base64.encode64("#{@token.token}:X")}"
      result = JSON.parse(response.body)
      expect(result['bikes'].is_a?(Array)).to be_truthy
      expect(response.response_code).to eq(200)
    end
    it "403s if read_bikes_spec isn't in token" do
      get '/api/v3/me/bikes', format: :json, access_token: @token.token
      expect(response.response_code).to eq(403)
    end
  end
end