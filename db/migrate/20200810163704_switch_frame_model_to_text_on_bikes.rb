class SwitchFrameModelToTextOnBikes < ActiveRecord::Migration[5.2]
  def change
    change_column :bikes, :frame_model, :text
  end
end
