# Production rates are set outside the seeds
MarketplaceFeeSchedule.create!(platform_fee_percent: 9, platform_fee_cap_cents: 69_00, processing_fee_percent: 3, start_at: 1.second.from_now)
