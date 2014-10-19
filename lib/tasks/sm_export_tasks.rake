desc "Create frame_makers and push to redis"
task :sm_import_frame_makers => :environment do
  out_file = File.join(Rails.root,'/frame_makers.json')
  output = File.open(out_file, "w")
  Manufacturer.frames.each do |mnfg|
    i = {
      id: mnfg.id,
      term: mnfg.name,
      score: mnfg.bikes.count,
      data: {}
    }
    output.puts i.to_json
  end  
  result = `soulmate load frame_makers < frame_makers.json`
  puts result
end

desc "Create frame_makers and push to redis"
task :sm_import_manufacturers => :environment do
  out_file = File.join(Rails.root,'/frame_makers.json')
  output = File.open(out_file, "w")
  Manufacturer.all.each do |mnfg|
    score = mnfg.bikes.count + mnfg.components.count
    i = {
      id: mnfg.id,
      term: mnfg.name,
      score: score,
      data: {}
    }
    output.puts i.to_json
  end  
  result = `soulmate load manufacturers < frame_makers.json`
  puts result
end
