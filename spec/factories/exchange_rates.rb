# == Schema Information
#
# Table name: exchange_rates
#
#  id         :bigint           not null, primary key
#  from       :string           not null
#  rate       :float            not null
#  to         :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_exchange_rates_on_from_and_to  (from,to) UNIQUE
#
FactoryBot.define do
  factory :exchange_rate do
    from { "USD" }
    to { 3.times.map { ("A".."Z").entries.sample }.join }
    rate { rand.truncate(2) }

    factory :exchange_rate_to_eur do
      to { "EUR" }
      rate { 0.88 }
    end

    factory :exchange_rate_to_mxn do
      to { "MXN" }
      rate { 20.35 }
    end
  end
end
