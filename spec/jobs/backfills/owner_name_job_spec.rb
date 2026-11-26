require "rails_helper"

RSpec.describe Backfills::OwnerNameJob, type: :job do
  let(:user) { FactoryBot.create(:user_confirmed, name: nil) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user:) }
  let(:ownership) { bike.current_ownership }

  it "restores the name typed at registration that claiming wiped" do
    # The state the old claim left behind
    ownership.update_columns(registration_info: {"user_name" => "Cardinal Rider"}, owner_name: nil)

    described_class.new.perform
    expect(ownership.reload.owner_name).to eq "Cardinal Rider"
    expect(bike.reload.owner_name).to eq "Cardinal Rider"
  end
end
