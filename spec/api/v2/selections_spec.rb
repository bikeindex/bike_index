require 'spec_helper'

describe 'Selections API V2' do
  describe 'colors' do 
    it "responds on index" do
      selection = FactoryGirl.create(:color)
      get '/api/v2/selections/colors'
      response.code.should == '200'
      result = JSON.parse(response.body)['colors'][0]
      expect(result["name"]).to eq(selection.name)
    end
  end

  describe 'component_types' do 
    it "responds on index with pagination" do
      selection = FactoryGirl.create(:ctype)
      get '/api/v2/selections/component_types'
      response.code.should == '200'
      result = JSON.parse(response.body)['component_types'][0]
      expect(result["name"]).to eq(selection.name)
    end
  end

  describe 'cycle_types' do 
    it "responds on index with pagination" do
      selection = FactoryGirl.create(:cycle_type)
      get '/api/v2/selections/cycle_types'
      response.code.should == '200'
      result = JSON.parse(response.body)['cycle_types'][0]
      expect(result["name"]).to eq(selection.name)
    end
  end

  describe 'frame_materials' do 
    it "responds on index with pagination" do
      selection = FactoryGirl.create(:frame_material)
      get '/api/v2/selections/frame_materials'
      response.code.should == '200'
      result = JSON.parse(response.body)['frame_materials'][0]
      expect(result["name"]).to eq(selection.name)
    end
  end

  describe 'handlebar_types' do 
    it "responds on index with pagination" do
      selection = FactoryGirl.create(:handlebar_type)
      get '/api/v2/selections/handlebar_types'
      response.code.should == '200'
      result = JSON.parse(response.body)['handlebar_types'][0]
      expect(result["name"]).to eq(selection.name)
    end
  end
  

  describe 'wheel_size' do 
    it "responds on index with pagination" do
      wheel_size = FactoryGirl.create(:wheel_size)
      FactoryGirl.create(:wheel_size)
      get '/api/v2/selections/wheel_sizes?per_page=1'
      expect(response.header['Total']).to eq('2')
      pagination_link = "<http://www.example.com/api/v2/selections/wheel_sizes?page=2&per_page=1>; rel=\"last\", <http://www.example.com/api/v2/selections/wheel_sizes?page=2&per_page=1>; rel=\"next\""
      expect(response.header['Link']).to eq(pagination_link)
      response.code.should == '200'
      result = JSON.parse(response.body)['wheel_sizes'][0]
      expect(result["iso_bsd"]).to eq(wheel_size.iso_bsd)
      expect(result["popularity"]).to eq(wheel_size.popularity)
    end
  end
end