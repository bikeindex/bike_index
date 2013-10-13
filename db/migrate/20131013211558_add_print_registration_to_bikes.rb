class AddPrintRegistrationToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :print_registration, :string
  end
end
