require "flipper"
require "flipper/adapters/active_record"

Flipper.configure do |config|
  config.default do
    adapter = Flipper::Adapters::ActiveRecord.new
    Flipper.new(adapter)
  end
end

Flipper.register(:superusers) do |actor|
  actor.respond_to?(:superuser?) && actor.superuser?
end

Flipper.register(:paid_organization_users) do |actor|
  actor.respond_to?(:invoiced_org?) && actor.invoiced_org?
end
