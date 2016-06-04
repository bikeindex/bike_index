require 'spec_helper'

describe Api::V1::OrganizationsController do
  describe 'show' do
    it 'returns unauthorized unless organizations api token present' do
      organization = FactoryGirl.create(:organization)
      get :show, id: organization.slug, format: :json
      expect(response.code).to eq('401')
    end

    it 'returns the organization info if the token is present' do
      organization = FactoryGirl.create(:organization)
      options = { id: organization.slug, access_token: ENV['ORGANIZATIONS_API_ACCESS_TOKEN'] }
      get :show, options, format: :json
      expect(response.code).to eq('200')
      result = JSON.parse(response.body)
      expect(result['name']).to eq(organization.name)
      expect(result['can_add_bikes']).to be_falsey
    end

    it 'returns the organization info if the org token is present' do
      organization = FactoryGirl.create(:organization)
      options = { id: organization.slug, access_token: organization.access_token }
      get :show, options, format: :json
      expect(response.code).to eq('200')
      result = JSON.parse(response.body)
      expect(result['name']).to eq(organization.name)
      expect(result['can_add_bikes']).to be_falsey
    end

    it "404s if the organization doesn't exist" do
      body = { id: 'fake_organization_slug', access_token: ENV['ORGANIZATIONS_API_ACCESS_TOKEN'] }
      get :show, body, format: :json
      expect(response).to redirect_to(api_v1_not_found_url)
    end
  end
end
