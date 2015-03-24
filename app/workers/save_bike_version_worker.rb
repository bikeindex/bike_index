class SaveBikeVersionWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'versioner'
  sidekiq_options backtrace: true

  def perform(bike_id)
    if ENV['VERSIONER_LOCATION'].present?
      bike = Bike.unscoped.find(bike_id)
      bike_json = BikeV2ShowSerializer.new(bike, root: false).as_json
      out = JSON.pretty_generate(bike_json)
      File.open("#{ENV['VERSIONER_LOCATION']}/bikes/#{bike_id}.json", 'w') {|f| f.write(out) }
      puts `ruby #{ENV['VERSIONER_LOCATION']}/versioner.rb -l '#{ENV['VERSIONER_LOCATION']}' -i #{bike_id}`
    end
  end

end