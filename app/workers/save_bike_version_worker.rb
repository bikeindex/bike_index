class SaveBikeVersionWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'versioner'
  sidekiq_options backtrace: true

  def perform(bike_id)
    bike = Bike.unscoped.find(bike_id)
    bike_json = BikeV2ShowSerializer.new(bike, root: false).to_json.gsub("'", '\'')
    File.open("#{ENV['VERSIONER_LOCATION']}/bikes/#{bike_id}.json", 'w+') {|f| f.write(bike_json) }
    `ruby #{ENV['VERSIONER_LOCATION']}/versioner.rb -l '#{ENV['VERSIONER_LOCATION']}'  -i #{bike_id}`
  end

end