require "rails_helper"

RSpec.describe UserSerializer do
  let(:user) { FactoryBot.create(:user) }
  let!(:organization_user) { FactoryBot.create(:organization_role_claimed, user: user) }
  subject { UserSerializer.new(user.reload) }

  let(:target) do
    {
      something: "fadf"
    }
  end
  it "renders" do
    pp subject
  end
end
