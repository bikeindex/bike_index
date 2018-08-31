require "spec_helper"

RSpec.describe PaidFeature, type: :model do
  it_behaves_like "friendly_slug_findable"
  it_behaves_like "amountable"
end
