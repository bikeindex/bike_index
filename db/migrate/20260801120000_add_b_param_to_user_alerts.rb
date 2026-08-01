class AddBParamToUserAlerts < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :user_alerts, :b_param, index: {algorithm: :concurrently}

    # The unfinished_registration alert is refreshed off a user's own registrations
    add_index :b_params, :creator_id, where: "created_bike_id IS NULL",
      name: "index_b_params_on_creator_id_without_bike", algorithm: :concurrently
  end
end
