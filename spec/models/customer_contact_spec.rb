require 'spec_helper'

describe CustomerContact do
  describe 'validations' do
    it { is_expected.to validate_presence_of :user_email }
    it { is_expected.to validate_presence_of :creator_email }
    # it { should validate_presence_of :creator_id }
    it { is_expected.to validate_presence_of :contact_type }
    it { is_expected.to validate_presence_of :bike_id }
    it { is_expected.to validate_presence_of :title }
    it { is_expected.to validate_presence_of :body }
    it { is_expected.to belong_to :user }
    it { is_expected.to belong_to :creator }
    it { is_expected.to belong_to :bike }
    it { is_expected.to serialize :info_hash }
  end

  describe 'normalize_email_and_find_user' do
    it 'finds email and associate' do
      user = FactoryGirl.create(:user)
      cc = CustomerContact.new
      allow(cc).to receive(:user_email).and_return(user.email)
      cc.normalize_email_and_find_user
      expect(cc.user_id).to eq(user.id)
    end
    it 'has before_save_callback_method defined as a before_save callback' do
      expect(CustomerContact._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:normalize_email_and_find_user)).to eq(true)
    end
  end
end
