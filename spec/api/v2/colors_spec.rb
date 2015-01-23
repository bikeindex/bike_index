require 'spec_helper'

describe 'Colors API V2' do
  describe 'root' do 
    it "responds on index with pagination" do
      selection = FactoryGirl.create(:color)
      get '/api/v2/colors'
      response.code.should == '200'
      result = JSON.parse(response.body)['colors'][0]
      expect(result["name"]).to eq(selection.name)
    end
  end
  
end