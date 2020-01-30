class AddStateToBikeAndCreationState < ActiveRecord::Migration[5.2]
  def change
    add_column :bikes, :state, :integer, default: 0
    add_column :creation_states, :state, :integer, default: 0
  end
end
