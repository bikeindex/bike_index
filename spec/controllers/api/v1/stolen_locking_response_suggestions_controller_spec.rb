require 'spec_helper'

describe Api::V1::StolenLockingResponseSuggestionsController do
  describe 'index' do
    it 'loads the page' do
      get :index, format: :json
      # pp response.body
      expect(response.code).to eq('200')
      result = JSON.parse(response.body)
      expect(result['locking_defeat_descriptions'].count).to eq(6)
      expect(result['locking_descriptions'].count).to eq(8)
    end
  end   
end
