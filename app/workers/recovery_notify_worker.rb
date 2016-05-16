class RecoveryNotifyWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify'
  sidekiq_options backtrace: true

  def perform(stolenRecord_id)
    stolenRecord = StolenRecord.unscoped.find(stolenRecord_id)
    return true if stolenRecord.recovery_posted
    require 'httparty'
    options = {
      key: ENV['RECOVERY_APP_KEY'],
      api_url: ENV['BASE_URL'] + "/api/v1/bikes/#{stolenRecord.bike.id}",
      theft_information: {
        stolenRecord_id: stolenRecord_id,
        date_stolen: stolenRecord.date_stolen,
        latitude: stolenRecord.latitude,
        longitude: stolenRecord.longitude
      },
      recovery_information: {
        date_recovered: stolenRecord.date_recovered
      }
    }
    if stolenRecord.can_share_recovery
      options[:recovery_information][:recovery_story] = stolenRecord.recovery_share
      options[:recovery_information][:tweet] = stolenRecord.recovery_tweet
    end

    response = HTTParty.post(ENV['RECOVERY_APP_URL'],
      body: options.to_json,
      headers: { 'Content-Type' => 'application/json' })

    if response.code == 200
      stolenRecord.update_attribute :recovery_posted, true
    end
  end

end
