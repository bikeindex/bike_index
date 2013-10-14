class AddAdditionalRegistrationInformationToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :additional_registration, :string
  end
end
