require "rails_helper"

RSpec.describe Ctype, type: :model do
  it_behaves_like "friendly_slug_findable"
end
