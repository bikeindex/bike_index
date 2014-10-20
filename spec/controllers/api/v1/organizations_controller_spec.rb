require 'spec_helper'

describe Api::V1::OrganizationsController do

  describe :show do
    it "should return unauthorized unless organizations api token present" do 
      organization = FactoryGirl.create(:organization)
      get :show, id: organization.slug, format: :json
      response.code.should eq("401")
    end

    it "should return the organization info if the token is present" do 
      organization = FactoryGirl.create(:organization)
      options = { id: organization.slug, access_token: ENV['ORGANIZATIONS_API_ACCESS_TOKEN']}
      get :show, options, format: :json
      response.code.should eq("200")
      result = JSON.parse(response.body)
      result['name'].should eq(organization.name)
      result['can_add_bikes'].should be_false
    end

    it "should return the organization info if the org token is present" do 
      organization = FactoryGirl.create(:organization)
      options = { id: organization.slug, access_token: organization.access_token}
      get :show, options, format: :json
      response.code.should eq("200")
      result = JSON.parse(response.body)
      result['name'].should eq(organization.name)
      result['can_add_bikes'].should be_false
    end

    it "should 404 if the organization doesn't exist" do 
      body = { id: 'fake_organization_slug', access_token: ENV['ORGANIZATIONS_API_ACCESS_TOKEN']}
      get :show, body, format: :json
      response.should redirect_to(api_v1_not_found_url)
    end
  end

end
