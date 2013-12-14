class AddPdfToBikes < ActiveRecord::Migration
  def change
    add_column :bikes, :pdf, :string
  end
end
