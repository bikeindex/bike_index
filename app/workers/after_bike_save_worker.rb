class AfterBikeSaveWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'afterwards', backtrace: true, :retry => false

  def perform(bike_id)
    bike = Bike.unscoped.where(id: bike_id).first
    DuplicateBikeFinderWorker.perform_async(bike_id)
    if bike.present? && !bike.fake_deleted
      bike_json = BikeV2ShowSerializer.new(bike, root: false).as_json
      bike_json.delete(:registration_updated_at)
      out = JSON.pretty_generate(bike_json.merge(updator_id: bike.updator_id))
    else
      deleted = true
      out = JSON.pretty_generate({deleted: true})
    end
    
    fpath = "#{ENV['VERSIONER_LOCATION']}/bikes/#{bike_id}.json"
    if ENV['VERSIONER_LOCATION'].present? && should_write_update?(fpath, out, deleted || false)
      File.open(fpath, 'w') {|f| f.write(out) }
      `ruby #{ENV['VERSIONER_LOCATION']}/versioner.rb -l '#{ENV['VERSIONER_LOCATION']}' -i #{bike_id}` if Rails.env.production?
      WebhookRunner.new.after_bike_update(bike_id)
    end
    out
  end

  def should_write_update?(fpath, content, deleted)
    if File.exist?(fpath)
      return true if deleted
      return true unless File.read(fpath) == content
    else
      return true unless deleted
    end
    false
  end 

end
