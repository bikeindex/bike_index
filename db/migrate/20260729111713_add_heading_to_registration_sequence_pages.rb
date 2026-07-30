class AddHeadingToRegistrationSequencePages < ActiveRecord::Migration[8.1]
  def change
    add_column :registration_sequence_pages, :heading, :string
  end
end
