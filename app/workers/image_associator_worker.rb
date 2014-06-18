class ImageAssociatorWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'updates'
  sidekiq_options backtrace: true
    
  def perform
    BParam.where(image_processed: false).where('image IS NOT NULL').each do |b_param|
      next unless b_param.created_bike.present?
      BikeCreatorAssociator.new(b_param).attach_photo(b_param.created_bike)
    end
  end

end