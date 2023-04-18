class AddMarkedRemainingByIdToGraduatedNotifications < ActiveRecord::Migration[6.1]
  def change
    add_reference :graduated_notifications, :marked_remaining_by
  end
end
