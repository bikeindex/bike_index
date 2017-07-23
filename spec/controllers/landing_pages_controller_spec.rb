require 'spec_helper'

describe LandingPagesController do
  include_context :page_content_values
  describe 'show' do
    it 'renders revised_layout' do
      FactoryGirl.create(:organization, short_name: 'University')
      get :show, organization_id: 'university'
      expect(response.status).to eq(200)
      expect(response).to render_template('show')
      expect(response).to render_with_layout('application_revised')
      expect(title).to eq 'University Bike Registration'
    end
  end

  %w(for_shops for_advocacy for_law_enforcement for_schools).each do |landing_type|
    describe landing_type do
      it 'renders with correct title' do
        get landing_type.to_sym, preview: true
        expect(response.status).to eq(200)
        expect(response).to render_template(landing_type)
        expect(response).to render_with_layout('application_revised')
        if landing_type == 'for_advocacy'
          expect(title).to eq 'Bike Index for Advocacy Organizations'
        else
          expect(title).to eq "Bike Index #{landing_type.titleize.gsub(/\AF/, 'f')}"
        end
      end
    end
  end
end
