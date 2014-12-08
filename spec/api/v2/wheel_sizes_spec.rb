require 'spec_helper'

describe 'Wheel Sizes API V2' do
  describe 'root' do 
    it "responds on index with pagination" do
      wheel_size = FactoryGirl.create(:wheel_size)
      FactoryGirl.create(:wheel_size)
      get '/api/v2/wheel_sizes?per_page=1'
      expect(response.header['Total']).to eq('2')
      pagination_link = "<http://www.example.com/api/v2/wheel_sizes?page=2&per_page=1>; rel=\"last\", <http://www.example.com/api/v2/wheel_sizes?page=2&per_page=1>; rel=\"next\""
      expect(response.header['Link']).to eq(pagination_link)
      response.code.should == '200'
      result = JSON.parse(response.body)['wheel_sizes'][0]
      expect(result["iso_bsd"]).to eq(wheel_size.iso_bsd)
      expect(result["popularity"]).to eq(wheel_size.popularity)
    end
  end
  
  describe 'find by iso_bsd' do 
    it "returns one with from an id" do
      wheel_size = FactoryGirl.create(:wheel_size)
      get "/api/v2/wheel_sizes/#{wheel_size.iso_bsd}"
      result = response.body
      response.code.should == '200'
      expect(JSON.parse(result)['wheel_size']['iso_bsd']).to eq(wheel_size.iso_bsd)
    end

    it "responds with missing" do 
      get "/api/v2/wheel_sizes/10"
      response.code.should == '404'
      expect(JSON(response.body)["message"].present?).to be_true
    end
  end
end