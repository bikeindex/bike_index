class ImageAssociatorWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'updates'
  sidekiq_options backtrace: true
    
  def perform
    BParam.where(image_processed: false).where('image IS NOT NULL').each do |bikeParam|
      next unless bikeParam.created_bike.present?
      BikeCreatorAssociator.new(bikeParam).attach_photo(bikeParam.created_bike)
    end
  end

end