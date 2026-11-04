module ImageJobs
  class AttachBlobJob < ApplicationJob
    sidekiq_options queue: "high_priority"

    def perform(b_param_id, bike_id)
      b_param = BParam.find_by(id: b_param_id)
      bike = Bike.unscoped.find_by(id: bike_id)
      return if b_param.blank? || bike.blank?

      BikeServices::Creator.new.attach_blob(b_param, bike)
    end
  end
end
