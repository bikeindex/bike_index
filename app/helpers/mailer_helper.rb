module MailerHelper
  def render_donation?(organization = nil)
    true unless organization&.is_invoiced?
  end

  def render_supporters?(organization = nil)
    false
    # Disabled in PR#3616
    # if organization.present?
    #   return false if organization.bike_shop? || organization.paid_money?
    # end
    # true
  end
end
