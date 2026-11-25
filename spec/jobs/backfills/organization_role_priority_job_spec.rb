require "rails_helper"

RSpec.describe Backfills::OrganizationRolePriorityJob, type: :job do
  let(:instance) { described_class.new }
  let(:user) { FactoryBot.create(:user_confirmed) }
  let!(:organization_roles) do
    [3.days.ago, 1.hour.ago, 2.days.ago].map do |created_at|
      FactoryBot.create(:organization_role_claimed, user:, created_at:)
    end
  end
  # The migration defaulted every role to 0, which is the state the job runs against
  before { OrganizationRole.where(user_id: user.id).update_all(priority: 0) }

  it "numbers the user's roles by when they were created" do
    instance.perform

    expect(OrganizationRole.ordered_for(user).pluck(:id))
      .to eq([organization_roles[0].id, organization_roles[2].id, organization_roles[1].id])
    expect(OrganizationRole.ordered_for(user).pluck(:priority)).to eq([0, 1, 2])
  end

  it "numbers each user separately" do
    other_user_role = FactoryBot.create(:organization_role_claimed)
    OrganizationRole.where(id: other_user_role.id).update_all(priority: 0)

    instance.perform

    expect(other_user_role.reload.priority).to eq 0
    expect(OrganizationRole.ordered_for(user).pluck(:priority)).to eq([0, 1, 2])
  end
end
