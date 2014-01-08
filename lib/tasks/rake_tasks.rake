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
    paint = Paint.fuzzy_name_find(bike.frame_paint_description)
    if paint.present?
      bike.paint_id = paint.id
    else
      paint = Paint.create(name: bike.frame_paint_description)
      bike.paint_id = paint.id
    end
    bike.save
  end
end