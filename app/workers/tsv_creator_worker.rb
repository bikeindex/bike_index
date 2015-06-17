class TsvCreatorWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'updates'
  sidekiq_options backtrace: true
    
  def perform(tsv_method)
    TsvCreator.new.send(tsv_method)
  end

end