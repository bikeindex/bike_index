# == Schema Information
#
# Table name: logged_searches
#
#  id                :bigint           not null, primary key
#  city              :string
#  duration_ms       :integer
#  endpoint          :integer
#  includes_query    :boolean          default(FALSE)
#  ip_address        :string
#  latitude          :float
#  log_line          :text
#  longitude         :float
#  neighborhood      :string
#  page              :integer
#  processed         :boolean          default(FALSE)
#  query_items       :jsonb
#  request_at        :datetime
#  serial_normalized :string
#  stolenness        :integer
#  street            :string
#  zipcode           :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  country_id        :bigint
#  organization_id   :bigint
#  request_id        :uuid
#  state_id          :bigint
#  user_id           :bigint
#
# Indexes
#
#  index_logged_searches_on_country_id       (country_id)
#  index_logged_searches_on_organization_id  (organization_id)
#  index_logged_searches_on_request_id       (request_id)
#  index_logged_searches_on_state_id         (state_id)
#  index_logged_searches_on_user_id          (user_id)
#
require "rails_helper"

RSpec.describe LoggedSearch, type: :model do
  describe "ENDPOINT_ENUM" do
    let(:endpoint_enum) { LoggedSearch::ENDPOINT_ENUM }
    it "has separate values" do
      expect(endpoint_enum.keys.count).to eq endpoint_enum.values.uniq.count
    end
  end
  describe "factory" do
    let(:logged_search) { FactoryBot.create(:logged_search) }
    it "is valid" do
      expect(logged_search).to be_valid
    end
    context "with associations" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:user) { FactoryBot.create(:user) }
      let(:logged_search1) { FactoryBot.create(:logged_search, organization: organization) }
      let(:logged_search2) { FactoryBot.create(:logged_search, user: user) }
      it "is valid" do
        expect(logged_search1).to be_valid
        expect(logged_search1.reload.organization_id).to eq organization.id

        expect(logged_search2).to be_valid
        expect(logged_search2.reload.user_id).to eq user.id
      end
    end
  end
end
