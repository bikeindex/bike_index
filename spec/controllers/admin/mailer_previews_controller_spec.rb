require 'spec_helper'

describe Admin::MailerPreviewsController do
  include_context :logged_in_as_super_admin
  describe 'index' do
    it 'renders' do
        get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe 'show' do
    context 'unknown template_name' do
      it 'raises not found' do
        expect do
          get :show, id: 'not_at_template'
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    MailerIntegration.templates_config.map { |t| t['name'] }.each do |template_name|
      context template_name do
        xit 'renders' do
          get :show, id: template_name
          expect(response.status).to eq(200)
          expect(response).to render_template(template_name)
        end
      end
    end
  end
end