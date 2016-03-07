require 'spec_helper'

describe MailerIntegration do
  describe 'templates' do
    it 'returns the full list of different emails' do
      expect(MailerIntegration.templates.keys.count).to eq(9)
      expect(MailerIntegration.templates.keys.include?(:welcome_email)).to be_true
    end
  end

  describe 'mailer_array' do
    it 'returns the array sparkpost expects' do
      args = { something: 'cool', foo: 'bar' }
      expect(MailerIntegration).to receive(:template_body).with(:welcome_email) { 'template BODY' }
      result = MailerIntegration.new.integration_array(args: args, template: :welcome_email, to_email: 'user@bikeindex.org')
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
