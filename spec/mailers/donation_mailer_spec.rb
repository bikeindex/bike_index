require "rails_helper"

RSpec.describe DonationMailer, type: :mailer do
  let(:payment) { FactoryBot.create(:payment, kind: "donation") }

  describe "standard" do
    let(:mail) { DonationMailer.donation_email("donation_standard", payment) }
    it "renders email" do
      expect(mail.subject).to eq("Thank you for donating to Bike Index")
      expect(mail.to).to eq([payment.email])
      expect(mail.body.encoded).to match(/gavin/i)
      expect(mail.tag).to eq "donation"
      expect(mail.body.encoded).to_not match(/supported by/i)
    end
  end

  describe "notification kinds" do
    Notification.donation_kinds.each do |notification_kind|
      context notification_kind do
        let(:mail) { DonationMailer.donation_email(notification_kind, payment) }
        it "renders email" do
          expect(mail.subject).to eq("Thank you for donating to Bike Index")
          expect(mail.to).to eq([payment.email])
          expect(mail.tag).to eq "donation"
        end
      end
    end
  end
end
