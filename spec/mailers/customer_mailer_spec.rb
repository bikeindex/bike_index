require 'spec_helper'

describe CustomerMailer do
  let(:user) { FactoryGirl.create(:user) }

  describe 'welcome_email' do
    it 'renders an email' do
      mail = CustomerMailer.welcome_email(user)
      expect(mail.subject).to eq('Welcome to Bike Index!')
      expect(mail.from).to eq(['contact@bikeindex.org'])
      expect(mail.to).to eq([user.email])
    end
  end

  describe 'confirmation_email' do
    it 'renders email' do
      mail = CustomerMailer.confirmation_email(user)
      expect(mail.subject).to eq("Please confirm your Bike Index email!")
      expect(mail.to).to eq([user.email])
      expect(mail.from).to eq(["contact@bikeindex.org"])
    end
    context "partner signup" do
      let(:user) { FactoryGirl.create(:user_bikehub_signup) }
      it "renders bikehub partner email" do
        expect(user.partner_sign_up).to eq "bikehub"
        mail = CustomerMailer.confirmation_email(user)
        expect(mail.subject).to eq("Please confirm your Bike Index email!")
        expect(mail.to).to eq([user.email])
        expect(mail.from).to eq(["contact@bikeindex.org"])
      end
    end
  end

  describe 'password_reset_email' do
    it 'renders email' do
      user.set_password_reset_token
      mail = CustomerMailer.password_reset_email(user)
      expect(mail.subject).to eq('Instructions to reset your password')
      expect(mail.from).to eq(['contact@bikeindex.org'])
      expect(mail.body.encoded).to match(user.password_reset_token)
    end
  end

  describe 'additional_email_confirmation' do
    let(:user_email) { FactoryGirl.create(:user_email) }
    it 'renders email' do
      mail = CustomerMailer.additional_email_confirmation(user_email)
      expect(mail.subject).to match(/confirm/i)
      expect(mail.from).to eq(['contact@bikeindex.org'])
    end
  end

  describe 'invoice_email' do
    context 'donation' do
      let(:payment) { FactoryGirl.create(:payment, user: user) }
      it 'renders email' do
        mail = CustomerMailer.invoice_email(payment)
        expect(mail.subject).to eq('Thank you for supporting Bike Index!')
        expect(mail.to).to eq([user.email])
        expect(mail.from).to eq(['contact@bikeindex.org'])
        expect(mail.body.encoded).to match 'donation of'
      end
    end
    context 'payment' do
      let(:payment) { FactoryGirl.create(:payment, user: user, is_payment: true) }
      it 'renders email' do
        mail = CustomerMailer.invoice_email(payment)
        expect(mail.subject).to eq('Thank you for supporting Bike Index!')
        expect(mail.to).to eq([user.email])
        expect(mail.from).to eq(['contact@bikeindex.org'])
        expect(mail.body.encoded).to_not match 'donation of'
      end
    end
  end

  describe 'stolen_bike_alert_email' do
    let!(:ownership) { FactoryGirl.create(:ownership, bike: stolen_record.bike) }
    let(:stolen_record) { FactoryGirl.create(:stolen_record) }
    let(:notification_hash) do
      {
        notification_type: 'stolen_twitter_alerter',
        bike_id: stolen_record.bike.id,
        tweet_id: 69,
        tweet_string: 'STOLEN - something special',
        tweet_account_screen_name: 'bikeindex',
        tweet_account_name: 'Bike Index',
        tweet_account_image: 'https://pbs.twimg.com/profile_images/3384343656/33893b31d39d69fb4b85912489c497b0_bigger.png',
        location: 'Everywhere',
        retweet_screen_names: %w(someother_screename and_another)
      }
    end
    let(:customer_contact) { FactoryGirl.create(:customer_contact, info_hash: notification_hash, title: 'CUSTOM CUSTOMER contact Title', bike: stolen_record.bike) }
    it 'renders email' do
      mail = CustomerMailer.stolen_bike_alert_email(customer_contact)
      expect(mail.to).to eq([customer_contact.user_email])
      expect(mail.subject).to eq 'CUSTOM CUSTOMER contact Title'
      expect(mail.from).to eq(['contact@bikeindex.org'])
    end
  end

  describe 'recovered_from_link' do
    let(:cycle_type) { FactoryGirl.create(:cycle_type, name: 'Sikk Trike') }
    let(:bike) { FactoryGirl.create(:stolen_bike, cycle_type: cycle_type) }
    let(:stolen_record) { bike.current_stolen_record }
    let!(:ownership) { FactoryGirl.create(:ownership, bike: stolen_record.bike) }
    let(:recovered_description) { 'Bike Index helped me find my stolen bike and get it back!' }
    before { stolen_record.add_recovery_information(recovered_description: recovered_description) }
    it 'renders email' do
      mail = CustomerMailer.recovered_from_link(stolen_record)
      expect(mail.to).to eq([bike.owner_email])
      expect(mail.subject).to eq 'Your sikk trike has been marked recovered!'
      expect(mail.from).to eq(['bryan@bikeindex.org'])
      expect(mail.body.encoded).to match recovered_description
    end
  end

  describe 'admin_contact_stolen_email' do
    let!(:ownership) { FactoryGirl.create(:ownership, bike: stolen_record.bike) }
    let(:stolen_record) { FactoryGirl.create(:stolen_record) }
    let(:user) { FactoryGirl.create(:admin, email: 'something@stuff.com') }
    let(:customer_contact) do
      CustomerContact.create(user_email: stolen_record.bike.owner_email,
                             creator_email: user.email,
                             body: 'some message',
                             contact_type: 'stolen_contact',
                             bike_id: stolen_record.bike.id,
                             title: 'some title')
    end
    it 'renders email' do
      mail = CustomerMailer.admin_contact_stolen_email(customer_contact)
      expect(mail.subject).to eq('some title')
      expect(mail.body.encoded).to match('some message')
      expect(mail.reply_to).to eq(['something@stuff.com'])
      expect(mail.from).to eq(['contact@bikeindex.org'])
    end
  end

  describe 'stolen_notification_email' do
    let(:stolen_record) { FactoryGirl.create(:stolen_record) }
    let!(:ownership) { FactoryGirl.create(:ownership, bike: stolen_record.bike) }
    let(:stolen_notification) { FactoryGirl.create(:stolen_notification, message: 'Test Message', reference_url: 'something.com', bike: stolen_record.bike) }
    it 'renders email and update sent_dates' do
      mail = CustomerMailer.stolen_notification_email(stolen_notification)
      expect(mail.subject).to eq(stolen_notification.default_subject)
      expect(mail.from.count).to eq(1)
      expect(mail.from.first).to eq('bryan@bikeindex.org')
      expect(mail.body.encoded).to match(stolen_notification.message)
      expect(mail.body.encoded).to match(stolen_notification.reference_url)
      stolen_notification.reload
      expect(stolen_notification.send_dates).to be_present
      expect(stolen_notification.send_dates[0]).to eq(stolen_notification.updated_at.to_i)
      stolen_note = StolenNotification.where(id: stolen_notification.id).first
      mail2 = CustomerMailer.stolen_notification_email(stolen_note)
      expect(mail2.subject).to eq(stolen_notification.default_subject)
      stolen_notification.reload
      expect(stolen_notification.send_dates[1]).to be > stolen_notification.updated_at.to_i - 2
    end
  end

  describe 'updated_terms_email' do
    let(:user) { FactoryGirl.create(:user) }
    it 'renders email' do
      mail = CustomerMailer.updated_terms_email(user)
      expect(mail.subject).to eq 'Bike Index Terms and Privacy Policy Update'
      expect(mail.from.count).to eq(1)
      expect(mail.from.first).to eq('lily@bikeindex.org')
      expect(mail.body.encoded).to_not match 'vendor terms'
    end
  end
end
