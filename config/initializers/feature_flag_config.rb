require 'redis'

$redis = Redis.new
$rollout = Rollout.new($redis)

$rollout.define_group(:developer) { |user| user.developer }
$rollout.define_group(:superuser) { |user| user.superuser }
