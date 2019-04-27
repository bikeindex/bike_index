require "redis"

$redis = Redis.new
$rollout = Rollout.new($redis)

# Not using developer? and superuser? methods here - which we should use everywhere else - because of performance
$rollout.define_group(:developer) { |user| user.developer }
$rollout.define_group(:superuser) { |user| user.superuser }
$rollout.define_group(:developer_or_superuser) { |user| user.superuser || user.developer }

$rollout.activate_group(:preview, :developer_or_superuser)
