class AddResolvedMessageToImpoundClaims < ActiveRecord::Migration[5.2]
  def change
    add_column :impound_claims, :resolved_message, :text
  end
end
