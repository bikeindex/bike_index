class AddNotesToInvoicesAndKindToOrganizations < ActiveRecord::Migration
  def change
    add_column :invoices, :notes, :text
    add_column :organizations, :kind, :integer
  end
end
