class EmailDelivererWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'notify'
  sidekiq_options backtrace: true

  def perform(mailer_method, args = {})
    vars = MailerVariables.new(mailer_method).var_hash(args)
    MailerIntegration.mailer_class(mailer_method).send(mailer_method, vars).deliver_now
  end
end
