task :start do
  system 'redis-server &'
  system 'bundle exec foreman start -f Procfile_development'
end

desc "Create stolen tsv"
task :create_stolen_tsv => :environment do
  out_file = File.join(Rails.root,'/current_stolen_bikes.tsv')
  headers = "Make\tModel\tSerial\tDescription\tArticleOrGun\tDateOfTheft\tCaseNumber\tLEName\tLEContact\tComments\n"
  output = File.open(out_file, "w")
  output.puts headers
  StolenRecord.where(current: true).where(approved: true).includes(:bike).each do |sr|
    output.puts sr.tsv_row if sr.tsv_row.present?
  end
  output
  
  uploader = TsvUploader.new
  uploader.store!(output)
  output.close
  puts uploader.url
end


desc 'update old bike colors'
task :update_colors => :environment do
  black_id = Color.find_by_name('Black').id
  Paint.all.each do |paint|
    next if paint.color_id.present?
    paint.save
    bikes = paint.reload.bikes.where(primary_frame_color_id: black_id)
    bikes.each do |bike|
      next if bike.secondary_frame_color_id.present?
      next unless bike.primary_frame_color_id == black_id
      bike.primary_frame_color_id = paint.color_id
      bike.secondary_frame_color_id = paint.secondary_color_id
      bike.tertiary_frame_color_id = paint.tertiary_color_id
      bike.save
    end
  end
end