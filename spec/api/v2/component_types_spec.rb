require 'spec_helper'

describe 'Component types API V2' do
  describe 'root' do 
    it "responds on index with pagination" do
      selection = FactoryGirl.create(:ctype)
      get '/api/v2/component_types'
      response.code.should == '200'
      result = JSON.parse(response.body)['component_types'][0]
      expect(result["name"]).to eq(selection.name)
    end
  end
  
end