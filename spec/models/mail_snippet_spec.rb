require 'spec_helper'

describe MailSnippet do
  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to belong_to :organization }
    it { is_expected.to validate_uniqueness_of(:organization_id).scoped_to(:name) }
  end

  describe 'matching_opts' do
    it 'finds an enabled snippet in the proximity' do
      # Creating far too many objects here. Need to reduce that...
      mail_snippet = FactoryGirl.create(:location_triggered_mail_snippet)
      country = FactoryGirl.create(:country, iso: 'US')
      bike = FactoryGirl.create(:bike, stolen: true)
      stolen_record = FactoryGirl.create(:stolen_record, bike: bike, city: 'New York', country_id: country.id)
      bike.update_attribute :current_stolen_record_id, stolen_record.id
      result = MailSnippet.matching_opts(bike: bike, mailer_method: 'ownership_invitation_email')
      expect(result).to eq(mail_snippet)
    end
  end

  describe 'disable_if_blank' do
    it 'has before_save_callback_method defined for clean_frame_size' do
      expect(MailSnippet._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:disable_if_blank)).to eq(true)
    end
    it 'sets unenabled if body is blank' do
      mail_snippet = MailSnippet.new(is_enabled: true, body: nil)
      expect(mail_snippet.is_enabled).to be_truthy
      mail_snippet.disable_if_blank
      expect(mail_snippet.is_enabled).to be_falsey
    end
  end
end
