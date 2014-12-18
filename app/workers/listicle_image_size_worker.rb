class ListicleImageSizeWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'carrierwave'
  sidekiq_options :backtrace => true
  sidekiq_options unique: true
    
  def perform(id)
    listicle = Listicle.find(id)
    return true unless listicle.image.present?
    listicle.process_image_upload = true
    listicle.image.recreate_versions! 
    listicle.save
    listicle.blog.save if listicle.blog.present?
  end

end
