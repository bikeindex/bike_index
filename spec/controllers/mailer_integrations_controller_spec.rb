require 'spec_helper'

describe MailerIntegrationsController do
  describe 'index' do
    before do
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
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
        before do
          get :show, id: template_name
        end
        it { should respond_with(:success) }
        it { should render_template(template_name) }
      end
    end
  end
end
