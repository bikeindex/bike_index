class AddAlertableToUserAlerts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :user_alerts, :alertable, polymorphic: true,
      index: {algorithm: :concurrently}
  end
end
