class SaveBikeVersionWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'versioner', backtrace: true, :retry => false

  def perform(bike_id)
    if ENV['VERSIONER_LOCATION'].present?
      bike = Bike.unscoped.find(bike_id)
      bike_json = BikeV2ShowSerializer.new(bike, root: false).as_json
      bike_json.delete(:registration_updated_at)
      out = JSON.pretty_generate(bike_json.merge(updator_id: bike.updator_id))
      File.open("#{ENV['VERSIONER_LOCATION']}/bikes/#{bike_id}.json", 'w') {|f| f.write(out) }
      puts `ruby #{ENV['VERSIONER_LOCATION']}/versioner.rb -l '#{ENV['VERSIONER_LOCATION']}' -i #{bike_id}`
      out
    end
  end

end