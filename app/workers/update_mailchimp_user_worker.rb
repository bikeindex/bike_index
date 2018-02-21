class UpdateMailchimpUserWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify', backtrace: true, retry: false
  API_KEY = ENV['MAILCHIMP_API_KEY']
  LIST_ID = ENV['MAILCHIMP_LIST_ID']

  def perform(user_id)
    user = User.find(user_id)
    return true unless user.add_to_mailchimp?
    mailchimp_user(user).upsert(
      body: {
        email_address: user.email,
        status_if_new: 'subscribed',
        merge_fields: mailchimp_user_attributes(user)
      }
    )
  end

  def mailchimp_user_attributes(user)
    {
      NAME: user.name,
      SIGNED_UP: user.created_at.strftime('%m/%d/%Y'),
      BIKE_COUNT: user.bikes.count
    }.delete_if { |_, v| v.nil? }
  end

  def self.required_merge_fields
    # Tags are upcased and max 10 characters
    [
      { name: 'Name', tag: 'NAME', type: 'text' },
      { name: 'Signed up at', tag: 'SIGNED_UP' }.merge(date_options),
      { name: 'Registered bike count', tag: 'BIKE_COUNT', type: 'number' }
    ]
  end

  def self.date_options
    { type: 'date', options: { date_format: 'MM/DD/YYYY' } }
  end

  def mailchimp_request
    Gibbon::Request.new(api_key: API_KEY, symbolize_keys: true)
  end

  def mailchimp_user(user)
    hashed_email = Digest::MD5.hexdigest(user.email.downcase)
    mailchimp_request.lists(LIST_ID).members(hashed_email)
  end

  # This is required when using a new list. When adding merge tags, only do this for one merge tag
  # If you get an error like: "Data did not match any of the schemas described in anyOf"
  # But it should only be run once!
  def self.add_merge_fields
    required_merge_fields.each do |attrs|
      new.mailchimp_request.lists(LIST_ID).merge_fields.create(body: attrs)
    end
  end
end
