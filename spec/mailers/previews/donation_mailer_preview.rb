# Preview emails at /rails/mailers/donation_mailer
class DonationMailerPreview < ActionMailer::Preview
  def standard
    payment = Payment.donation.last
    DonationMailer.standard(payment)
  end
end
