class AddPaidMoneyToOrganizations < ActiveRecord::Migration[8.1]
  def up
    add_column :organizations, :paid_money, :boolean, default: false, null: false

    # Nothing re-saves every organization, so without this the ones that have paid read false
    execute <<~SQL.squish
      UPDATE organizations SET paid_money = true WHERE id IN (
        SELECT organization_id FROM invoices
        WHERE is_active AND amount_due_cents > 0 AND amount_paid_cents >= amount_due_cents
      )
    SQL
  end

  def down
    remove_column :organizations, :paid_money
  end
end
