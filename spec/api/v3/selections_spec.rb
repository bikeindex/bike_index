require 'spec_helper'

describe 'Selections API V3' do
  describe 'colors' do
    it 'responds on index' do
      selection = FactoryGirl.create(:color)
      get '/api/v3/selections/colors'
      expect(response.code).to eq('200')
      result = JSON.parse(response.body)['colors'][0]
      expect(result['name']).to eq(selection.name)
    end
  end

  describe 'component_types' do
    it 'responds on index with pagination' do
      selection = FactoryGirl.create(:ctype)
      get '/api/v3/selections/component_types'
      expect(response.code).to eq('200')
      result = JSON.parse(response.body)['component_types'][0]
      expect(result['name']).to eq(selection.name)
    end
  end

  describe 'cycle_types' do
    it 'responds on index with pagination' do
      selection = FactoryGirl.create(:cycle_type)
      get '/api/v3/selections/cycle_types'
      expect(response.code).to eq('200')
      result = JSON.parse(response.body)['cycle_types'][0]
      expect(result['name']).to eq(selection.name)
    end
  end

  describe 'frame_materials' do
    it 'responds on index with pagination' do
      selection = FactoryGirl.create(:frame_material)
      get '/api/v3/selections/frame_materials'
      expect(response.code).to eq('200')
      result = JSON.parse(response.body)['frame_materials'][0]
      expect(result['name']).to eq(selection.name)
    end
  end

  describe 'front_gear_types' do
    it 'responds on index with pagination' do
      selection = FactoryGirl.create(:front_gear_type)
      get '/api/v3/selections/front_gear_types'
      expect(response.code).to eq('200')
      result = JSON.parse(response.body)['front_gear_types'][0]
      expect(result['name']).to eq(selection.name)
    end
  end

  describe 'rear_gear_types' do
    it 'responds on index with pagination' do
      selection = FactoryGirl.create(:rear_gear_type)
      get '/api/v3/selections/rear_gear_types'
      expect(response.code).to eq('200')
      result = JSON.parse(response.body)['rear_gear_types'][0]
      expect(result['name']).to eq(selection.name)
    end
  end

  describe 'handlebar_types' do
    it 'responds on index with pagination' do
      selection = FactoryGirl.create(:handlebar_type)
      get '/api/v3/selections/handlebar_types'
      expect(response.code).to eq('200')
      result = JSON.parse(response.body)['handlebar_types'][0]
      expect(result['name']).to eq(selection.name)
    end
  end

  describe 'propulsion_types' do
    it 'responds on index with pagination' do
      selection = FactoryGirl.create(:propulsion_type)
      get '/api/v3/selections/propulsion_types'
      expect(response.code).to eq('200')
      result = JSON.parse(response.body)['propulsion_types'][0]
      expect(result['name']).to eq(selection.name)
    end
  end

  describe 'wheel_size' do
    it 'responds on index with pagination' do
      wheel_size = FactoryGirl.create(:wheel_size)
      FactoryGirl.create(:wheel_size)
      get '/api/v3/selections/wheel_sizes?per_page=1'
      expect(response.header['Total']).to eq('2')
      pagination_link = '<http://www.example.com/api/v3/selections/wheel_sizes?page=2&per_page=1>; rel="last", <http://www.example.com/api/v3/selections/wheel_sizes?page=2&per_page=1>; rel="next"'
      expect(response.header['Link']).to eq(pagination_link)
      expect(response.code).to eq('200')
      result = JSON.parse(response.body)['wheel_sizes'][0]
      expect(result['iso_bsd']).to eq(wheel_size.iso_bsd)
      expect(result['popularity']).to eq(wheel_size.popularity)
    end
  end
end
