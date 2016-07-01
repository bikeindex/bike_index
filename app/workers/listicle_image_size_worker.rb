class ListicleImageSizeWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'carrierwave'
  sidekiq_options backtrace: true
    
  def perform(id)
    listicle = Listicle.find(id)
    return true unless listicle.image.present?
    unless listicle.image_width.present?
      width, height = `identify -format "%wx%h" #{listicle.image_url}`.split(/x/)
      listicle.image_width = width.gsub(/\D/,'').to_i
      listicle.image_height = height.gsub(/\D/,'').to_i
    end
    if listicle.crop_top_offset.present?
      listicle.process_image_upload = true
      listicle.image.recreate_versions! 
    end
    listicle.save
    listicle.blog.save if listicle.blog.present?
  end

end
