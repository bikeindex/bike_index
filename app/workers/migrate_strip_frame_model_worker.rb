class MigrateStripFrameModelWorker < ApplicationWorker
  def perform(bike_id)
    bike = Bike.unscoped.find_by_id(bike_id)
    normalized_model = InputNormalizer.string(bike.frame_model)
    if bike.frame_model != normalized_model
      bike.update_column :frame_model, normalized_model
    end
  end
end
