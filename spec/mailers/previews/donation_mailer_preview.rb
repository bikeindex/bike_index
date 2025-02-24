# Preview emails at /rails/mailers/donation_mailer
class DonationMailerPreview < ActionMailer::Preview
  def donation_standard
    payment = Payment.donation.last
    DonationMailer.donation_email("donation_standard", payment)
  end

  def donation_second
    payment = Payment.donation.last
    DonationMailer.donation_email("donation_second", payment)
  end

  def donation_stolen
    payment = Payment.donation.last
    DonationMailer.donation_email("donation_stolen", payment)
  end

  def donation_recovered
    payment = Payment.donation.last
    DonationMailer.donation_email("donation_recovered", payment)
  end

  def donation_promoted_alert
    payment = Payment.donation.last
    DonationMailer.donation_email("donation_promoted_alert", payment)
  end
end
