
# This is deprecated and should be removed or refactored eventually. Check AfterBikeSaveWorker
class WebhookRunner

  require 'httparty'
  
  def make_request(url)
    begin
      response = HTTParty.get(url,
        :headers => { 'Content-Type' => 'application/json' } )
      JSON.parse(response.body)
    rescue => e
      e.message
    end
  end

  def after_bike_update(bike_id)
    hook_urls(__method__.to_s).each do |url|
      make_request(url.gsub('#{bike_id}', bike_id.to_s))
    end
  end

  def after_user_update(user_id)
    hook_urls(__method__.to_s).each do |url|
      make_request(url.gsub('#{user_id}', user_id.to_s))
    end
  end

  def hook_urls(method)
    redis.lrange(redis_id(method.to_s), 0, 0)
  end

  def redis_id(method)
    "#{Rails.env[0..2]}_webhook_#{method}"
  end

  private

  def redis
    Redis.current
  end

end