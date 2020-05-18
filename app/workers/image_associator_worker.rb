class ImageAssociatorWorker < ApplicationWorker
  sidekiq_options queue: "high_priority"

  def perform
    BParam.unprocessed_image.with_bike.each do |b_param|
      BikeCreatorAssociator.new(b_param).attach_photo(b_param.created_bike)
    end
  end
end
