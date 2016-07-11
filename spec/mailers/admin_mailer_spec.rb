require 'spec_helper'

describe AdminMailer do
  describe 'feedback_notification_email' do
    before :each do
      @feedback = FactoryGirl.create(:feedback)
      @mail = AdminMailer.feedback_notification_email(@feedback)
    end
    it 'renders email' do
      expect(@mail.subject).to eq('New Feedback Submitted')
      expect(@mail.to).to eq(['contact@bikeindex.org'])
      expect(@mail.reply_to).to eq([@feedback.email])
    end
  end

  describe 'special_feedback_notification_email' do
    before :each do
      @bike = FactoryGirl.create(:bike)
      @feedback = FactoryGirl.create(:feedback, feedback_hash: { bike_id: @bike.id })
    end
    it 'sends a delete request email' do
      @feedback.update_attributes(feedback_type: 'bike_delete_request')
      mail = AdminMailer.feedback_notification_email(@feedback)
      expect(mail.subject).to eq('New Feedback Submitted')
      expect(mail.to).to eq(['contact@bikeindex.org'])
      expect(mail.reply_to).to eq([@feedback.email])
    end
    it 'sends a recovery email' do
      @feedback.update_attributes(feedback_type: 'bike_recovery')
      mail = AdminMailer.feedback_notification_email(@feedback)
      expect(mail.subject).to eq('New Feedback Submitted')
      expect(mail.to).to eq(['contact@bikeindex.org', 'bryan@bikeindex.org'])
      expect(mail.reply_to).to eq([@feedback.email])
    end
    it 'sends a stolen_information email' do
      @feedback.update_attributes(feedback_type: 'stolen_information')
      mail = AdminMailer.feedback_notification_email(@feedback)
      expect(mail.to).to eq(['bryan@bikeindex.org'])
    end
    it 'sends a serial update email' do
      @feedback.update_attributes(feedback_type: 'serial_update_request')
      mail = AdminMailer.feedback_notification_email(@feedback)
      expect(mail.subject).to eq('New Feedback Submitted')
      expect(mail.to).to eq(['contact@bikeindex.org'])
      expect(mail.reply_to).to eq([@feedback.email])
    end
    it 'sends a new org email' do
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      FactoryGirl.create(:membership, user: user, organization: organization)
      @feedback.update_attributes(feedback_hash: { organization_id: organization.id }, feedback_type: 'organization_created')
      mail = AdminMailer.feedback_notification_email(@feedback)
      expect(mail.reply_to).to eq([@feedback.email])
    end
  end

  context 'user_hidden bike' do
    let(:ownership) { FactoryGirl.create(:ownership, user_hidden: true) }
    let(:bike) { ownership.bike }
    let(:feedback) { FactoryGirl.create(:feedback, feedback_hash: { bike_id: bike.id }, feedback_type: 'bike_delete_request') }
    it "doesn't explode" do
      bike.update_attribute :hidden, true
      bike.reload
      expect(bike.user_hidden).to be_truthy
      mail = AdminMailer.feedback_notification_email(feedback)
      expect(mail.subject).to eq('New Feedback Submitted')
      expect(mail.to).to eq(['contact@bikeindex.org'])
      expect(mail.reply_to).to eq([feedback.email])
    end
  end

  describe 'no_admins_notification_email' do
    before :each do
      @organization = FactoryGirl.create(:organization)
      @mail = AdminMailer.no_admins_notification_email(@organization)
    end

    it 'renders email' do
      expect(@mail.to).to eq(['contact@bikeindex.org'])
      expect(@mail.subject).to match("doesn't have any admins")
    end
  end

  describe 'blocked_stolen_notification_email' do
    before :each do
      @stolen_notification = FactoryGirl.create(:stolen_notification, message: 'Test Message', subject: 'Test subject')
      @mail = AdminMailer.blocked_stolen_notification_email(@stolen_notification)
    end

    it 'renders email' do
      expect(@mail.subject[/blocked/i].present?).to be_truthy
      expect(@mail.body.encoded).to match(@stolen_notification.message)
    end
  end
end
