class AddCanonicalUrlToBlog < ActiveRecord::Migration
  def change
    add_column :blogs, :canonical_url, :string
  end
end
