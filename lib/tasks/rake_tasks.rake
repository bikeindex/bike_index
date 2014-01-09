# reprocess public_images

# Usage: rake carrierwave:reprocess
namespace :carrierwave do
  task :reprocess => :environment do
    PublicImage.all.each do |record|
      record.image.recreate_versions! if record.image?
    end

  end
end


task :switch_paints_over => :environment do
  Bike.where("frame_paint_description IS NOT NULL").each do |bike|
    if bike.frame_paint_description.present?
      paint = Paint.fuzzy_name_find(bike.frame_paint_description)
      paint = Paint.create(name: bike.frame_paint_description) unless paint.present?
      bike.update_attributes(paint_id: paint.id)
      puts "\n#{bike.id} - #{bike.paint.name}"
    end
  end
end