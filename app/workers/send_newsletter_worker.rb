class SendNewsletterWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify', backtrace: true, retry: false
  API_KEY = ENV['SPARKPOST_API_KEY']

  def client; @client ||= SimpleSpark::Client.new(api_key: API_KEY) end

  def perform(template, user_id = nil)
    return enqueue_mailing(template) unless user_id.present?

    # NOTE: it would be possible to do this more efficiently by mapping/plucking the user attributes we need
    # and then mass sending rather than doing it on a per user basis. But who cares for now
    client.transmissions.create(mailing_properties(template, User.find(user_id)))
  end

  def enqueue_mailing(template)
    User.confirmed.where(is_emailable: true).where.not(banned: true).pluck(:id)
        .each { |id| SendNewsletterWorker.perform_async(template, id) }
  end

  def mailing_properties(template, user)
    {
      options: { open_tracking: true, click_tracking: true },
      campaign_id: "#{template}_campaign",
      return_path: 'support@bikeindex.org',
      content: {
        template_id: template,
        use_draft_template: true
      },
      recipients:  [{ 
        address: { email: user.email, name: user.display_name },
        metadata: {},
        substitution_data: { name: user.name || '', user_id: user.username }
      }]
    }
  end
end
