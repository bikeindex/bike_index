require 'spec_helper'

describe 'Manufacturers API V2' do
  describe 'root' do
    it 'responds on index with pagination' do
      manufacturer = FactoryGirl.create(:manufacturer)
      FactoryGirl.create(:manufacturer)
      get '/api/v2/manufacturers?per_page=1'
      expect(response.header['Total']).to eq('2')
      pagination_link = '<http://www.example.com/api/v2/manufacturers?page=2&per_page=1>; rel="last", <http://www.example.com/api/v2/manufacturers?page=2&per_page=1>; rel="next"'
      expect(response.header['Link']).to eq(pagination_link)
      expect(response.code).to eq('200')
      # pp response.headers
      expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
      expect(response.headers['Access-Control-Request-Method']).to eq('*')
      expect(JSON.parse(response.body)['manufacturers'][0]['id']).to eq(manufacturer.id)
    end
  end

  describe 'find by id or name' do
    before :all do
      @manufacturer = FactoryGirl.create(:manufacturer)
    end
    it 'returns one with from an id' do
      get "/api/v2/manufacturers/#{@manufacturer.id}"
      result = response.body
      expect(response.code).to eq('200')
      expect(JSON.parse(result)['manufacturer']['id']).to eq(@manufacturer.id)
    end

    it 'responds with missing and cors headers' do
      get '/api/v2/manufacturers/10000'
      expect(response.code).to eq('404')
      expect(JSON(response.body)['error'].present?).to be_truthy
      expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
      expect(response.headers['Access-Control-Request-Method']).to eq('*')
      expect(response.headers['Content-Type'].match('json')).to be_present
    end

    it 'returns one from a name' do
      # THIS FAILS when we don't create a manufacturer in this block,
      # I've got no idea why
      manufacturer = FactoryGirl.create(:manufacturer, name: 'awesome')
      get '/api/v2/manufacturers/awesome'
      result = response.body
      expect(response.code).to eq('200')
      expect(JSON.parse(result)['manufacturer']['id']).to eq(manufacturer.id)
    end
  end

  describe 'JUST CRAZY 404' do
    it 'responds with missing and cors headers' do
      get '/api/v2/manufacturersdddd'
      # pp JSON.parse(response.body)
      expect(response.code).to eq('404')
      expect(JSON(response.body)['error'].present?).to be_truthy
      expect(response.headers['Access-Control-Allow-Origin']).to eq('*')
      expect(response.headers['Access-Control-Request-Method']).to eq('*')
      expect(response.headers['Content-Type'].match('json')).to be_present
    end
  end
end
