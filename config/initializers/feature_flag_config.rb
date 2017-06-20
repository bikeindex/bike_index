require 'redis'

$redis = Redis.new
$rollout = Rollout.new($redis)

$rollout.define_group(:developer) { |user| user.developer }
$rollout.define_group(:superuser) { |user| user.superuser }
$rollout.define_group(:developer_or_superuser) { |user| user.superuser || user.developer }

$rollout.activate_group(:preview, :developer_or_superuser)