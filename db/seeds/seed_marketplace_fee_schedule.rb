# Production rates are set outside the seeds.
# The seed clock is moved a week back, so this passes the future-only validation and has started by the time it returns
MarketplaceFeeSchedule.create!(platform_fee_percent: 9, platform_fee_cap_cents: 69_00, processing_fee_percent: 3, start_at: 1.second.from_now)
