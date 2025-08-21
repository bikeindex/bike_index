require "rails_helper"

RSpec.describe TheftAlertPlan, type: :model do
  it_behaves_like "amountable"
  it_behaves_like "currencyable"
end
