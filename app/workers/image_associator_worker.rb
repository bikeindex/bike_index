class ImageAssociatorWorker < ApplicationWorker
  sidekiq_options queue: "high_priority"

  def perform
    BParam.unprocessed_image.with_bike.each do |b_param|
      BikeCreator.new.attach_photo(b_param, b_param.created_bike)
    end
  end
end
