require 'rails_helper'

RSpec.describe StripeSubscription, type: :model do
  it_behaves_like "active_periodable"
end
