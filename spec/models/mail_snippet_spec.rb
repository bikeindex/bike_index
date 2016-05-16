require 'spec_helper'

describe MailSnippet do
  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
  end

  describe 'matching_opts' do
    it 'finds an enabled snippet in the proximity' do
      # Creating far too many objects here. Need to reduce that...
      mail_snippet = FactoryGirl.create(:mail_snippet)
      country = FactoryGirl.create(:country, iso: 'US')
      bike = FactoryGirl.create(:bike, stolen: true)
      stolenRecord = FactoryGirl.create(:stolenRecord, bike: bike, city: 'New York', country_id: country.id)
      bike.update_attribute :current_stolenRecord_id, stolenRecord.id
      result = MailSnippet.matching_opts(bike: bike, mailer_method: 'ownership_invitation_email')
      expect(result).to eq(mail_snippet)
    end
  end
end
