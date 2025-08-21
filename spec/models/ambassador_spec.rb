# == Schema Information
#
# Table name: users
#
#  id                                 :integer          not null, primary key
#  address_set_manually               :boolean          default(FALSE)
#  admin_options                      :jsonb
#  alert_slugs                        :jsonb
#  auth_token                         :string(255)
#  avatar                             :string(255)
#  banned                             :boolean          default(FALSE), not null
#  can_send_many_stolen_notifications :boolean          default(FALSE), not null
#  city                               :string
#  confirmation_token                 :string(255)
#  confirmed                          :boolean          default(FALSE), not null
#  deleted_at                         :datetime
#  description                        :text
#  developer                          :boolean          default(FALSE), not null
#  email                              :string(255)
#  instagram                          :string
#  last_login_at                      :datetime
#  last_login_ip                      :string
#  latitude                           :float
#  longitude                          :float
#  magic_link_token                   :text
#  my_bikes_hash                      :jsonb
#  name                               :string(255)
#  neighborhood                       :string
#  no_address                         :boolean          default(FALSE)
#  no_non_theft_notification          :boolean          default(FALSE)
#  notification_newsletters           :boolean          default(FALSE), not null
#  notification_unstolen              :boolean          default(TRUE)
#  partner_data                       :jsonb
#  password                           :text
#  password_digest                    :string(255)
#  phone                              :string(255)
#  preferred_language                 :string
#  show_bikes                         :boolean          default(FALSE), not null
#  show_instagram                     :boolean          default(FALSE)
#  show_phone                         :boolean          default(TRUE)
#  show_twitter                       :boolean          default(FALSE), not null
#  show_website                       :boolean          default(FALSE), not null
#  street                             :string
#  superuser                          :boolean          default(FALSE), not null
#  terms_of_service                   :boolean          default(FALSE), not null
#  time_single_format                 :boolean          default(FALSE)
#  title                              :text
#  token_for_password_reset           :text
#  twitter                            :string(255)
#  username                           :string(255)
#  vendor_terms_of_service            :boolean
#  when_vendor_terms_of_service       :datetime
#  zipcode                            :string(255)
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  address_record_id                  :bigint
#  country_id                         :integer
#  state_id                           :integer
#  stripe_id                          :string(255)
#
# Indexes
#
#  index_users_on_address_record_id         (address_record_id)
#  index_users_on_auth_token                (auth_token)
#  index_users_on_token_for_password_reset  (token_for_password_reset)
#
require "rails_helper"

RSpec.describe Ambassador, type: :model do
  describe ".all" do
    it "returns all ambassadors" do
      FactoryBot.create(:user)
      created_ambassadors = FactoryBot.create_list(:ambassador, 3).sort
      ambassadors = Ambassador.all.sort
      expect(ambassadors).to eq(created_ambassadors)
    end
  end

  describe "#ambassador_organizations" do
    it "returns any associated ambassador organizations" do
      ambassador = FactoryBot.create(:ambassador)
      FactoryBot.create_list(:organization_role_ambassador, 3, user: ambassador)
      FactoryBot.create_list(:organization_role_claimed, 2, user: ambassador)

      expect(ambassador.ambassador_organizations.count).to eq(4)
      expect(ambassador.organizations.count).to eq(6)
    end
  end

  describe "#current_ambassador_organization" do
    it "returns the most recently associated ambassador organization" do
      ambassador = FactoryBot.create(:ambassador)
      org1 = FactoryBot.create(:organization_ambassador)
      org2 = FactoryBot.create(:organization_ambassador)
      FactoryBot.create(:organization_role_ambassador, user: ambassador, organization: org2)
      new_ambassadorship = FactoryBot.create(:organization_role_ambassador, user: ambassador, organization: org1)
      FactoryBot.create(:organization_role_claimed, user: ambassador)

      current_org = ambassador.current_ambassador_organization

      expect(current_org).to eq(new_ambassadorship.organization)
      expect(ambassador.organizations.count).to eq(4)
    end
  end

  describe "#percent_complete" do
    context "given no associated tasks" do
      it "returns 0 as a Float" do
        ambassador = FactoryBot.create(:ambassador)
        expect(ambassador.percent_complete).to eq(0.0)
      end
    end

    context "given two completed of three tasks" do
      it "returns 2/3 as a Float rounded to 2" do
        ambassador = FactoryBot.create(:ambassador)
        FactoryBot.create_list(:ambassador_task_assignment, 2, :completed, ambassador: ambassador)
        FactoryBot.create(:ambassador_task_assignment, ambassador: ambassador)
        expect(ambassador.percent_complete).to eq(0.67)
      end
    end

    context "given three completed of three tasks" do
      it "returns 1" do
        ambassador = FactoryBot.create(:ambassador)
        FactoryBot.create_list(:ambassador_task_assignment, 2, :completed, ambassador: ambassador)
        expect(ambassador.percent_complete).to eq(1)
      end
    end
  end
end
