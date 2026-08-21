# frozen_string_literal: true

module Admin
  module InvoicesTable
    # Wherever admin lists invoices — the invoices index, an organization's invoices tab
    # and its show page, an organization feature. skip_discount_due drops the money
    # columns the organization page has no room for.
    class Component < ApplicationComponent
      def initialize(invoices:, render_sortable: false, display_organization: false, skip_discount_due: false)
        @invoices = invoices
        @render_sortable = render_sortable
        @display_organization = display_organization
        @skip_discount_due = skip_discount_due
      end

      private

      # An invoice whose organization row is gone entirely has nothing to link to
      def records = @invoices.reject { |invoice| organization_for(invoice).blank? }

      # An invoice outlives its organization being deleted, so unscoped for that - but the
      # association first, or this defeats the callers' includes(:organization)
      def organization_for(invoice)
        @organizations_by_id ||= {}
        @organizations_by_id[invoice.organization_id] ||=
          invoice.organization || Organization.unscoped.find_by_id(invoice.organization_id)
      end

      def invoice_link(invoice)
        link_to invoice.display_name.gsub(/invoice\s?/i, ""),
          edit_admin_organization_invoice_path(organization_id: organization_for(invoice).to_param,
            id: invoice.to_param)
      end

      def end_at_class(invoice)
        "text-danger" if invoice.subscription_end_at < Time.current
      end
    end
  end
end
