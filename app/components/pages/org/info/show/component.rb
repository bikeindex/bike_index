# frozen_string_literal: true

module Pages
  module Org
    module Info
      module Show
        # Every member's overview of the organization, and where its new admin lands after signing up.
        # return_to: where they were headed before signing up, e.g. connecting Lightspeed
        class Component < ApplicationComponent
          def initialize(organization:, current_user:, return_to: nil)
            @organization = organization
            @current_user = current_user
            @return_to = return_to
          end

          def before_render
            # limit, so a big organization doesn't count every row to learn it has 3
            @few_registrations = @organization.bikes.limit(3).count < 3
            # Roles rather than users, so an invite that hasn't been accepted counts
            @few_members = @organization.organization_roles.limit(3).count < 3
          end

          private

          def organization_id = @organization.to_param

          def admin? = @current_user.admin_of?(@organization)

          # is_invoiced? rather than paid_money?, which a $0 invoice - the usual endless one - leaves false
          def invoiced? = @organization.is_invoiced?

          def next_invoice_due_at = @organization.current_invoices.not_endless.minimum(:subscription_end_at)

          def endless_invoice? = @organization.current_invoices.endless.any?

          def new_passwordless_user? = @current_user.passwordless_user? && @current_user.created_at > 1.hour.ago
        end
      end
    end
  end
end
