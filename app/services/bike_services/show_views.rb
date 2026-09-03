# frozen_string_literal: true

module BikeServices
  module ShowViews
    extend Functionable

    # The perspectives the given user may view this bike as, each a [kind, org]
    # pair: [:owner, nil] (owners and superadmins), [:staff|:limited, org] admin
    # views, [:marketplace_preview, nil] and always [:public, nil].
    # preview_organization is the ?view_as target org, so a superuser can preview
    # any organization it names.
    def available(bike:, current_user:, organization:, preview_organization: nil)
      [
        ([:owner, nil] if (current_user.present? && bike.owner == current_user) || current_user&.superuser?),
        *organization_views(bike:, current_user:, organization:, preview_organization:),
        [:public, nil],
        ([:marketplace_preview, nil] if marketplace_preview?(bike:, current_user:))
      ].compact
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

    # Once a listing is published the public view carries it, so only a draft is
    # worth previewing — and only by whoever may see it before it's public
    def marketplace_preview?(bike:, current_user:)
      return false unless bike.status_with_owner?

      marketplace_listing = bike.current_marketplace_listing
      marketplace_listing&.draft? && marketplace_listing.authorized?(current_user)
    end

    # [role, organization] pairs. Superadmins may preview both staff and limited.
    def organization_views(bike:, current_user:, organization:, preview_organization: nil)
      viewable_organizations(bike:, current_user:, organization:, preview_organization:).flat_map do |org|
        roles = current_user.superuser? ? %i[staff limited] : [role_for(current_user, org)]
        roles.map { |role| [role, org] }
      end
    end

    # An org member's role: :staff when they can edit bikes, else :limited.
    def role_for(current_user, organization)
      current_user.member_bike_edit_of?(organization) ? :staff : :limited
    end

    def viewable_organizations(bike:, current_user:, organization:, preview_organization: nil)
      return [] if current_user.blank?

      orgs = if current_user.superuser?
        # A superuser may preview any org it names in ?view_as; brakebills (fully
        # paid) and ikes-bikes (unpaid) are seeded defaults for the switcher
        [organization, bike.organizations.first, preview_organization,
          Organization.friendly_find("brakebills"), Organization.friendly_find("ikes-bikes")]
      else
        current_user.organizations.to_a
      end
      orgs.compact.uniq.select { |org| current_user.authorized?(org) }
    end

    conceal :marketplace_preview?, :organization_views, :viewable_organizations, :role_for
  end
end
