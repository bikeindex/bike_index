# Contains methods used for display, which don't return HTML.
# Use OrganizationHelper for methods that do return HTML

# TODO: Figure out a more consistent way of handling Displayers while preserving Functionalness
class OrganizationDisplayer
  class << self
    def law_enforcement_missing_verified_features?(organization)
      organization.law_enforcement? && !organization.law_enforcement_features_enabled?
    end

    def bike_shop_display_integration_alert?(organization)
      organization.bike_shop? &&
        %w[no_pos broken_ascend_pos broken_lightspeed_pos].include?(organization.pos_kind) &&
        !organization.official_manufacturer?
    end

    def subscription_expired_alert?(organization)
      return false if organization&.invoices.blank? || organization.paid_money?

      organization.invoices.expired.any? do |invoice|
        invoice.was_active? && invoice.end_at > (Time.current - 3.months)
      end
    end

    def avatar?(organization)
      organization&.avatar.present?
    end
  end
end
