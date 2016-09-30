require 'spec_helper'

describe LandingPagesController do
  describe 'show' do
    it 'renders revised_layout' do
      FactoryGirl.create(:organization, short_name: 'University')
      get :show, organization_id: 'university'
      expect(response.status).to eq(200)
      expect(response).to render_template('show')
      expect(response).to render_with_layout('application_revised')
      title = response.body[/<title[^>]*>([^<]*)/, 1] # First matching group ;)
      expect(title).to eq 'University Bike Registration'
    end
  end
end
