# reprocess public_images

# Usage: rake carrierwave:reprocess
namespace :carrierwave do
  task :reprocess => :environment do
    PublicImage.all.each do |record|
      record.image.recreate_versions! if record.image?
    end

  end
end

desc "find new sold serials and make bikes"
task :set_book_slugs => :environment do
  Manufacturer.all.each do |mfg|
    mfg.book_slug = Slugifyer.book_slug(mfg.name)
    mfg.save
  end
end