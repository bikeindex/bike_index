class EmailUpdatedTermsWorker < ApplicationWorker
  sidekiq_options queue: "low_priority"
  sidekiq_options retry: false

  def perform
    return true unless redis.llen(enqueued_emails_key) > 0
    begin
      user_id = redis.lpop enqueued_emails_key
      user = User.where(id: user_id).first if user_id.present?
      return true unless user_id.present? && user.present?
      CustomerMailer.updated_terms_email(user).deliver_now
    rescue => e
      # rpush so that if we run into an error, we don't keep running the exact same one
      redis.rpush(enqueued_emails_key, user_id)
      raise e
    end
  end

  def enqueued_emails_key
    "#{Rails.env[0..2]}_email_updated_terms_user_ids"
  end

  # Should be the new cannonical way of using redis
  def self.redis
    # Basically, crib what is done in sidekiq
    raise ArgumentError, "requires a block" unless block_given?
    redis_pool.with { |conn| yield conn }
  end
end
