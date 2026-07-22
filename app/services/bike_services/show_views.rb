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

    # The perspective to render when no permitted ?view_as is requested.
    def default_view_for(bike:, current_user:, passive_organization:)
      if passive_organization.present? && current_user&.authorized?(passive_organization)
        return [current_user.member_bike_edit_of?(passive_organization) ? :staff : :limited, passive_organization]
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
        roles = if current_user.superuser?
          %i[staff limited]
        else
          [current_user.member_bike_edit_of?(org) ? :staff : :limited]
        end
        roles.map { |role| [role, org] }
      end
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

    conceal :organization_views, :viewable_organizations
  end
end
