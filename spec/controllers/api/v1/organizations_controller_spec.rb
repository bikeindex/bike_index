require 'spec_helper'

describe Api::V1::OrganizationsController do

  describe :show do
    it "should return unauthorized unless organizations api token present" do 
      get :show, id: 'something', format: :json
      response.code.should eq("401")
    end

    it "should return the organization info if the token is present" do 
      organization = FactoryGirl.create(:organization)
      body = { id: organization.slug, access_token: ENV['ORGANIZATIONS_API_ACCESS_TOKEN']}
      get :show, body, format: :json
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

  describe :find_or_create do 
    xit "should find the organization by the name" do 
      organization = FactoryGirl.create(:organization, name: 'the something bike something')
      body = { name: 'something bike something', access_token: ENV['ORGANIZATIONS_API_ACCESS_TOKEN']}
      get :find_or_create, body, format: :json
      result = JSON.parse(response.body)
      result['slug'].should eq(organization.slug)
    end
    it "should find the organization by the name" do 
      organization = FactoryGirl.create(:organization, name: 'something bike something')
      body = { name: 'The something bike something', access_token: ENV['ORGANIZATIONS_API_ACCESS_TOKEN']}
      get :find_or_create, body, format: :json
      result = JSON.parse(response.body)
      result['slug'].should eq(organization.slug)
    end
  end
      
end
