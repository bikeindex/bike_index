class MailerIntegration
  class << self
    def templates
      {
        welcome_email:
          { title: 'Welcome to the Bike Index!',
            description: 'Sent on sign up' },
        confirmation_email:
          { title: 'Welcome to the Bike Index!',
            description: 'Sent on signup, requires clicking to verify email' },
        invoice_email:
          { title: 'Thank you for supporting the Bike Index!',
            description: 'Sent on signing up to be a member of the Bike Index' },
        stolen_bike_alert_email:
          { title: nil,
            description: 'Email to Bike Index staff from support page' },
        password_reset_email:
          { title: 'Instructions to reset your password',
            description: 'Password reset requested, requires clicking link' },
        ownership_invitation_email:
          { title: 'Claim your bike on BikeIndex.org',
            description: 'Sent when a bike is registered' },
        stolen_ownership_invitation_email:
          { title: 'Your stolen bike',
            description: 'Sent when a stolen bike is registered' },
        organization_invitation_email:
          { title: nil,
            description: 'Sent when you are invited to be part of an organization' },
        stolen_notification_email:
          { title: nil,
            description: 'Sent when someone contacts the owner of a stolen bike through the contact form on Bike Index' }
      }
    end

    def template_body(template)

    end
  end

  def integration_array(template:, to_email:, args: {})
    [
      to_email,
      '"Bike Index" <contact@bikeindex.org>',
      (args[:title] || self.class.templates[template.to_sym][:title]),
      self.class.template_body(template),
      args
    ]
  end

end
