module Organized
  class DashboardController < Organized::BaseController
    before_action :set_fallback_period
    before_action :set_period, only: [:index]

    skip_before_action :ensure_not_ambassador_organization!, only: [:root]

    helper_method :bikes_for_graph

    def root
      if current_organization.ambassador?
        redirect_to organization_ambassador_dashboard_path
      else
        redirect_to organization_bikes_path
      end
    end

    def index
      # Only render this page if the organization has overview_dashboard (or it's a superuser)
      if !current_organization.overview_dashboard? && !current_user.superuser?
        redirect_to organization_bikes_path
        return
      end

      if current_organization.official_manufacturer?
        render_manufacturer
      else
        render_child_and_regional
      end
    end

    private

    def render_manufacturer
      manufacturer_id = current_organization.manufacturer_id
      @child_organizations = current_organization.organization_view_counts
      @manufacturer_bikes = Bike.unscoped.where(manufacturer_id: manufacturer_id).where(created_at: @time_range)
      stolen_records = StolenRecord.unscoped.left_joins(:bike).where(bikes: {manufacturer_id: manufacturer_id})
        .where(date_stolen: @time_range)
      @stolen_records = stolen_records.where(current: true)
      @recovered_records = stolen_records.where(current: false)
      render "manufacturer"
    end

    def render_child_and_regional
      @child_organizations = current_organization.child_organizations
      @bikes_in_organizations = Bike.unscoped.current.organization(current_organization.nearby_and_partner_organization_ids).where(created_at: @time_range)
      @bikes_in_organization_count = current_organization.bikes.where(created_at: @time_range).count
      @bikes_ever_registered_count = current_organization.bikes_ever_registered.where(created_at: @time_range).count

      if current_organization.regional?
        @bikes_not_in_organizations = current_organization.nearby_bikes.where.not(id: @bikes_in_organizations.pluck(:id)).where(created_at: @time_range)

        @bikes_in_child_organizations_count = Bike.organization(@child_organizations.pluck(:id)).where(created_at: @time_range).count
        @bikes_in_nearby_organizations_count = Bike.organization(current_organization.regional_ids).where(created_at: @time_range).count
        @bikes_in_region_not_in_organizations_count = @bikes_not_in_organizations.count
      end
      if current_organization.enabled?("claimed_ownerships")
        non_org_ownerships = Ownership.unscoped.joins(:bike).where(bikes: {creation_organization_id: current_organization.id})
          .where.not(owner_email: current_organization.users.pluck(:email))
        # In general, we're not using Bike#creation_organization_id - mostly, it should be accessed through ownerships
        # but this requires creation_organization_id for ease of joining
        @claimed_ownerships = non_org_ownerships.where(claimed_at: @time_range)
        # We added this - but it isn't a relevant metric for most organizations.
        # It's only relevant to organizations that register to themselves first (e.g. Pro's Closet)
        @ownerships_to_new_owner = non_org_ownerships.where(created_at: @time_range)
      end
      render "child_and_regional"
    end

    def set_fallback_period
      @period = "year" unless params[:period].present?
    end

    def earliest_period_date
      if current_organization.official_manufacturer?
        Time.parse("2017-01-01")
      else
        earliest_organization_period_date
      end
    end
  end
end
