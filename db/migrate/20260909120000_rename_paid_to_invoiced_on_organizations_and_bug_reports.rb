class RenamePaidToInvoicedOnOrganizationsAndBugReports < ActiveRecord::Migration[8.1]
  def change
    rename_column :organizations, :is_paid, :has_invoice
    rename_column :bug_reports, :is_paid_organization, :is_invoiced_organization
    rename_column :bug_reports, :is_paid_organization_staff, :is_invoiced_organization_staff
  end
end
