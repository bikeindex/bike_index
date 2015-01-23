require 'spec_helper'

describe 'frame materials API V2' do
  describe 'root' do 
    it "responds on index with pagination" do
      selection = FactoryGirl.create(:frame_material)
      get '/api/v2/frame_materials'
      response.code.should == '200'
      result = JSON.parse(response.body)['frame_materials'][0]
      expect(result["name"]).to eq(selection.name)
    end
  end
  
end