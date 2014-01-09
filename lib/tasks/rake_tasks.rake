# reprocess public_images

# Usage: rake carrierwave:reprocess
namespace :carrierwave do
  task :reprocess => :environment do
    PublicImage.all.each do |record|
      record.image.recreate_versions! if record.image?
    end

  end
end