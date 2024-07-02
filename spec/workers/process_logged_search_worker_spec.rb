require "rails_helper"

RSpec.describe ProcessLoggedSearchWorker, type: :job do
  let(:instance) { described_class.new }
  describe "perform" do
    context "user member of organization" do
      let!(:logged_search) { FactoryBot.create(:logged_search, user_id: user.id) }
      let(:user) { FactoryBot.create(:user_confirmed, :with_organization) }
      let(:organization) { user.reload.organizations.first }

      it "Process the logged_search" do
        expect(logged_search.user_id).to eq user.id
        expect(logged_search.organization_id).to be_nil
        expect(logged_search.processed?).to be_falsey

        instance.perform(logged_search.id)

        expect(logged_search.reload.processed?).to be_truthy
        expect(logged_search.organization_id).to eq organization.id
      end

      context 'user is superuser' do
        let(:user) { FactoryBot.create(:admin, :with_organization) }
        it "doesn't associate" do
          expect(logged_search.user_id).to eq user.id
          expect(logged_search.organization_id).to be_nil

          instance.perform(logged_search.id)

          expect(logged_search.reload.processed?).to be_truthy
          expect(logged_search.organization_id).to be_nil
        end
      end

      context 'organization_id is assigned' do
        before { logged_search.update(organization_id: 122) }
        it "doesn't update organization_id" do
          expect(logged_search.reload.processed?).to be_falsey

          instance.perform(logged_search.id)

          expect(logged_search.reload.processed?).to be_truthy
          expect(logged_search.organization_id).to eq 122
        end
      end
    end
  end
end
