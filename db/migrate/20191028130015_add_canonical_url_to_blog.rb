class AddCanonicalUrlToBlog < ActiveRecord::Migration[4.2]
  def change
    add_column :blogs, :canonical_url, :string
  end
end
