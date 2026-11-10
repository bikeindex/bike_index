class RemoveZipcodeAndStateIdFromSocialAccounts < ActiveRecord::Migration[8.1]
  def change
    change_table :social_accounts, bulk: true do |t|
      t.remove :zipcode, type: :string
      t.remove :state_id, type: :bigint
    end
  end
end
