# frozen_string_literal: true

module Admin
  module InvoicesTable
    # Wherever admin lists invoices — the invoices index, an organization's invoices tab
    # and its show page, an organization feature. render_sortable enables the sort links,
    # display_organization adds the owning organization, and skip_discount_due drops the
    # money columns the organization page has no room for.
    class Component < ApplicationComponent
      include Binxtils::SortableHelper

      def initialize(invoices:, render_sortable: false, display_organization: false, skip_discount_due: false)
        @invoices = invoices
        @render_sortable = render_sortable
        @display_organization = display_organization
        @skip_discount_due = skip_discount_due
      end

      private

      # SortableHelper's own are the "no controller" defaults, which would mark the wrong
      # column sorted
      def sort_column = helpers.sort_column

      def sort_direction = helpers.sort_direction

      def column(attribute, label)
        sortable(attribute, label, render_sortable: @render_sortable)
      end

      # An invoice outlives its organization being deleted, so unscoped - and a row with
      # no organization at all has nothing to link to
      def organization_for(invoice) = Organization.unscoped.find_by_id(invoice.organization_id)

      def invoice_path(invoice, organization)
        edit_admin_organization_invoice_path(organization_id: organization.to_param, id: invoice.to_param)
      end

      def invoice_number(invoice) = invoice.display_name.gsub(/invoice\s?/i, "")

      def end_at_class(invoice)
        "text-danger" if invoice.subscription_end_at < Time.current
      end
    end
  end
end
