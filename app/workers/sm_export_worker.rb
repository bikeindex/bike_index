class SmExportWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'updates'
  sidekiq_options backtrace: true
    
  def perform
    frame_makers_file = File.join(Rails.root,'/sm_import_frame_makers.json')
    output = File.open(frame_makers_file, "w")
    Manufacturer.frames.each { |m| output.puts m.sm_options.to_json }
    output.close

    manufacturers_file = File.join(Rails.root,'/sm_import_manufacturers.json')  
    output = File.open(manufacturers_file, "w")
    Manufacturer.all.each { |m| output.puts m.sm_options(true).to_json }
    result1 = `soulmate load frame_makers < sm_import_frame_makers.json`
    result2 = `soulmate load manufacturers < sm_import_manufacturers.json`
  end

end