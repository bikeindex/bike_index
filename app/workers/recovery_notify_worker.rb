class RecoveryNotifyWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify'
  sidekiq_options backtrace: true
    
  def perform(stolen_record_id)
    stolen_record = StolenRecord.unscoped.find(stolen_record_id)
    return true if stolen_record.recovery_posted
    require 'httparty'
    options = {
      key: ENV['RECOVERY_APP_KEY'],
      api_url: ROOT_URL + "/api/v1/bikes/#{stolen_record.bike.id}",
      theft_information: {
        stolen_record_id: stolen_record_id,
        date_stolen: stolen_record.date_stolen,
        location: stolen_record.address
      },
      recovery_information: {
        date_recovered: stolen_record.date_recovered
      }
    }
    if stolen_record.can_share_recovery
      options[:recovery_information][:recovery_story] = stolen_record.recovery_share
      options[:recovery_information][:tweet] = stolen_record.recovery_tweet
    end

    HTTParty.post(ENV['RECOVERY_APP_URL'],
      body: options.to_json,
      headers: { 'Content-Type' => 'application/json' })

    if response.code == '200'
      stolen_record.update_attribute :recovery_posted, true
    end
  end

end