require 'spec_helper'

describe 'Handlebar types V2' do
  describe 'root' do 
    it "responds on index with pagination" do
      selection = FactoryGirl.create(:handlebar_type)
      get '/api/v2/handlebar_types'
      response.code.should == '200'
      result = JSON.parse(response.body)['handlebar_types'][0]
      expect(result["name"]).to eq(selection.name)
    end
  end
  
end