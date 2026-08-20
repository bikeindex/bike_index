module OrgServices
  module Displayer
    extend Functionable

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

    def retrieval_link_url(obj)
      if obj.is_a?(ParkingNotification)
        return nil if obj.retrieval_link_token.blank?

        routes.bike_url(obj.bike.to_param, parking_notification_retrieved: obj.retrieval_link_token)
      elsif obj.is_a?(GraduatedNotification)
        return nil if obj.marked_remaining_link_token.blank?

        routes.bike_url(obj.bike.to_param, graduated_notification_remaining: obj.marked_remaining_link_token)
      end
    end

    def registration_field_label(organization, field_slug, strip_tags: false)
      txt = organization&.registration_field_labels&.dig(field_slug.to_s)
      return nil unless txt.present?

      strip_tags ? Binxtils::InputNormalizer.sanitize(txt) : txt.html_safe
    end

    #
    # private below here
    #

    def routes
      Rails.application.routes.url_helpers
    end

    conceal :routes
  end
end
