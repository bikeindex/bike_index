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
      expect(template_names.count).to eq 10
      expect(template_names.include?('welcome_email')).to be_true
    end
  end

  describe 'template_body' do
    MailerIntegration.templates_config.each do |template|
      context template['name'] do
        before :all do
          @rendered_string = MailerIntegration.template_body(template['name'])
        end

        it 'renders' do
          expect(@rendered_string).to be_present
        end

        it 'includes all expected substitutions args' do
          # separated tests for each substitution add significant delay (and failures print the whole template)
          # instead test against everything at once, then print all failures if there are any
          substitutions = template['args'] && template['args'].map { |arg| "#{arg}}}" }
          if substitutions && substitutions.detect { |s| !@rendered_string.include?(s) }
            missing = []
            substitutions.each do |arg|
              missing << "{{#{arg}" unless @rendered_string.match(arg)
            end
            raise "#{template['name']} does not include expected substitutions #{missing.join(', ')}"
          end
        end
      end
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
