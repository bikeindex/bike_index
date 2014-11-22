require 'spec_helper'

describe Api::V1::StolenLockingResponseSuggestionsController do
  
  describe :index do
    it "loads the page" do
      get :index, format: :json
      # pp response.body
      response.code.should eq('200')
      result = JSON.parse(response.body)
      result['locking_defeat_descriptions'].count.should eq(6)
      result['locking_descriptions'].count.should eq(8)
    end
  end   
end
