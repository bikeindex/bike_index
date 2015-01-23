require 'spec_helper'

describe 'Cycle_types API V2' do
  describe 'root' do 
    it "responds on index with pagination" do
      selection = FactoryGirl.create(:cycle_type)
      get '/api/v2/cycle_types'
      response.code.should == '200'
      result = JSON.parse(response.body)['cycle_types'][0]
      expect(result["name"]).to eq(selection.name)
    end
  end
  
end