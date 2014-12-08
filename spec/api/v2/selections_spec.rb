require 'spec_helper'

describe 'Selections API V2' do
  describe 'root' do 
    it "responds on index with pagination" do
      color = FactoryGirl.create(:color)
      get '/api/v2/selections?type=colors'
      response.code.should == '200'
      result = JSON.parse(response.body)['selections'][0]
      expect(result["name"]).to eq(color.name)
    end
  end
  
end