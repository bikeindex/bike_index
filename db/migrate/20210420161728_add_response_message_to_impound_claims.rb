class AddResponseMessageToImpoundClaims < ActiveRecord::Migration[5.2]
  def change
    add_column :impound_claims, :response_message, :text
  end
end
