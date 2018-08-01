require 'spec_helper'

describe MailSnippet do
  describe 'validations' do
    it { is_expected.to validate_presence_of :name }
    it { is_expected.to belong_to :organization }
    it { is_expected.to validate_uniqueness_of(:organization_id).scoped_to(:name) }
  end

  describe 'disable_if_blank' do
    it 'sets unenabled if body is blank' do
      mail_snippet = MailSnippet.new(is_enabled: true, body: nil, name: "welcome")
      expect(mail_snippet.is_enabled).to be_truthy
      mail_snippet.save
      expect(mail_snippet.is_enabled).to be_falsey
      expect(mail_snippet.kind).to eq "welcome"
    end
  end
end
