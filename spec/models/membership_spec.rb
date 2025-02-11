require 'rails_helper'

RSpec.describe Membership, type: :model do
  it_behaves_like "active_periodable"

end
