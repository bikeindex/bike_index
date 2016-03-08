require 'spec_helper'

describe MailerIntegration do
  let(:config_keys) { %w(name title description args) }
  describe 'template_dir' do
    it 'returns the expected rails path' do
      expect(MailerIntegration.templates_path.is_a?(Pathname)).to be_true
      expect(MailerIntegration.templates_path.to_s).to match(/app.views.mailer_integration/)
    end
  end

  describe 'templates_config' do
    it 'returns the full list of different emails' do
      template_names = MailerIntegration.templates_config.map { |t| t['name'] }
      MailerIntegration.templates_config.each do |template|
        expect(template.keys).to eq config_keys
      end
      expect(template_names.count).to eq 9
      expect(template_names.include?('welcome_email')).to be_true
    end
  end

  describe 'template_body' do
    # test rendering each of the templates from template_config
    # test that it includes the args from config
    # test that it doesn't include args not in config
    it 'returns the template body as a string' do
      rendered_string = MailerIntegration.template_body('welcome_email')
      expect(rendered_string).to match('<h1>Welcome to the Bike Index</h1>')
    end
  end

  describe 'template_config' do
    context 'existing template_config' do
      it 'returns the config hash' do
        config = MailerIntegration.new.template_config('stolen_notification_email')
        expect(config.keys).to eq config_keys
      end
    end
    context 'non existing template config' do
      it 'raises active record not found' do
        expect do
          MailerIntegration.new.template_config('unknown template')
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'mailer_array' do
    it 'returns the array sparkpost expects' do
      args = { something: 'cool', foo: 'bar' }
      expect(MailerIntegration).to receive(:template_body).with('welcome_email') { 'template BODY' }
      result = MailerIntegration.new.integration_array(args: args, template_name: 'welcome_email', to_email: 'user@bikeindex.org')
      target = [
        'user@bikeindex.org',
        '"Bike Index" <contact@bikeindex.org>',
        'Welcome to the Bike Index!',
        'template BODY',
        args
      ]
      expect(result).to eq(target)
    end
  end
end
