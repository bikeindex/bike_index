require "rails_helper"

RSpec.describe PromotedAlertPlan, type: :model do
  it_behaves_like "amountable"
  it_behaves_like "currencyable"
end
