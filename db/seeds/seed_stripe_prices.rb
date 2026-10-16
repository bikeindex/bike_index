# Placeholder ids; StripeJobs::UpdatePricesJob deactivates them when it syncs the real prices
{basic: 500, plus: 1500, patron: 5000}.each do |membership_level, amount_cents|
  StripePrice.create!(membership_level:, interval: "monthly", amount_cents:, active: true,
    stripe_id: "price_seed_#{membership_level}_monthly")
  StripePrice.create!(membership_level:, interval: "yearly", amount_cents: amount_cents * 10, active: true,
    stripe_id: "price_seed_#{membership_level}_yearly")
end
puts "Done seeding stripe prices!"
