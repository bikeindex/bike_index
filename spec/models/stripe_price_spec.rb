require "rails_helper"

RSpec.describe StripePrice, type: :model do
  it_behaves_like "amountable"
  it_behaves_like "currencyable"
end
