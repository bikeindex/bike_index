# frozen_string_literal: true

module Admin
  module OrganizationPaymentsTable
    # The payments made against an organization's invoices, on its invoices tab.
    class Component < ApplicationComponent
      def initialize(organization:)
        @organization = organization
      end

      private

      def payments = @organization.payments

      def invoice_path(payment)
        edit_admin_organization_invoice_path(organization_id: @organization.to_param, id: payment.invoice.to_param)
      end
    end
  end
end
