# frozen_string_literal: true

module BikeServices
  module ShowViews
    extend Functionable

    # The perspectives the given user may view this bike as, each a [kind, org]
    # pair: [:owner, nil] (owners and superadmins), [:staff|:limited, org] admin
    # views, and always [:public, nil].
    def available(bike:, current_user:, organization:)
      [
        ([:owner, nil] if (current_user.present? && bike.owner == current_user) || current_user&.superuser?),
        *organization_views(bike:, current_user:, organization:),
        [:public, nil]
      ].compact
    end

    # Whether view is one the user may see (an entry from #available).
    def permitted?(view, available_views:)
      available_views.include?(view)
    end

    # The ?view_as string for a [kind, organization] view.
    def view_param(view)
      kind, organization = view
      organization ? "#{organization.to_param}.#{kind}" : kind.to_s
    end

    # The perspective to render when no permitted ?view_as is requested.
    def default_view_for(bike:, current_user:, organization:)
      if organization.present? && current_user&.authorized?(organization)
        return [role_for(current_user, organization), organization]
      end
      return [:owner, nil] if current_user.present? && bike.owner == current_user

      [:public, nil]
    end

    #
    # private below here
    #

    # [role, organization] pairs. Superadmins may preview both staff and limited.
    def organization_views(bike:, current_user:, organization:)
      viewable_organizations(bike:, current_user:, organization:).flat_map do |org|
        roles = current_user.superuser? ? %i[staff limited] : [role_for(current_user, org)]
        roles.map { |role| [role, org] }
      end
    end

    # An org member's role: :staff when they can edit bikes, else :limited.
    def role_for(current_user, organization)
      current_user.member_bike_edit_of?(organization) ? :staff : :limited
    end

    def viewable_organizations(bike:, current_user:, organization:)
      return [] if current_user.blank?

      orgs = if current_user.superuser?
        [organization, bike.organizations.first, Organization.friendly_find("brakebills")]
      else
        current_user.organizations.to_a
      end
      orgs.compact.uniq.select { |org| current_user.authorized?(org) }
    end

    conceal :organization_views, :viewable_organizations, :role_for
  end
end
