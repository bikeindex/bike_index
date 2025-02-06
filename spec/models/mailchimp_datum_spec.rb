require "rails_helper"

RSpec.describe MailchimpDatum, type: :model do
  let(:organization) { FactoryBot.create(:organization, kind: organization_kind) }
  let(:organization_kind) { "bike_shop" }
  let(:empty_data) { {lists: [], tags: [], interests: [], merge_fields: {"bikes" => 0, "number_of_donations" => 0}} }

  describe "find_or_create_for" do
    before { Sidekiq::Worker.clear_all }

    context "user" do
      let(:user) { FactoryBot.create(:user, email: "test@stuff.com") }
      it "does not creates if not required" do
        mailchimp_datum = MailchimpDatum.find_or_create_for(user)
        expect(mailchimp_datum.lists).to eq([])
        expect(mailchimp_datum.no_subscription_required?).to be_truthy
        expect(mailchimp_datum.id).to be_blank
        expect(mailchimp_datum.data.except("merge_fields")).to eq empty_data.except(:merge_fields).merge(tags: ["in_bike_index"]).as_json
        expect(mailchimp_datum.subscriber_hash).to eq "4108acb6069e48c2eec39cb7ecc002fe"
        expect(UpdateMailchimpDatumWorker.jobs.count).to eq 0
      end
      context "organization admin" do
        let!(:organization_user) { FactoryBot.create(:organization_role_claimed, role: "admin", user: user, organization: organization) }
        it "creates and then finds for the user" do
          expect(user.organizations.pluck(:id)).to eq([organization.id])
          mailchimp_datum = MailchimpDatum.find_or_create_for(user)
          expect(mailchimp_datum.lists).to eq(["organization"])
          expect(mailchimp_datum.subscribed?).to be_truthy
          expect(mailchimp_datum.on_mailchimp?).to be_falsey
          expect(mailchimp_datum.id).to be_present
          expect(mailchimp_datum.user_id).to eq user.id
          expect(user.reload.mailchimp_datum&.id).to eq mailchimp_datum.id
          expect(UpdateMailchimpDatumWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([mailchimp_datum.id])
          expect {
            mailchimp_datum.update(updated_at: Time.current)
          }.to_not change(UpdateMailchimpDatumWorker.jobs, :count)
          expect(mailchimp_datum.should_update?).to be_truthy

          # Destroying the user updates mailchimp
          user.destroy
          expect {
            mailchimp_datum.reload
            mailchimp_datum.update(updated_at: Time.current)
          }.to change(UpdateMailchimpDatumWorker.jobs, :count).by 1
          mailchimp_datum.reload
          expect(mailchimp_datum.user_deleted?).to be_truthy
          expect(mailchimp_datum.status).to eq "archived"
          expect(mailchimp_datum.user_id).to be_present
        end
        context "membership removed" do
          it "is archived" do
            mailchimp_datum = MailchimpDatum.find_or_create_for(user)
            expect(mailchimp_datum.lists).to eq(["organization"])
            expect(mailchimp_datum.subscribed?).to be_truthy
            expect(mailchimp_datum.on_mailchimp?).to be_falsey
            Sidekiq::Worker.clear_all
            membership.destroy
            expect(AfterUserChangeWorker.jobs.count).to eq 1
            id = mailchimp_datum.id
            mailchimp_datum = MailchimpDatum.find(id) # Unmemoize
            expect(mailchimp_datum.mailchimp_organization&.id).to be_blank
            mailchimp_datum.update(updated_at: Time.current)
            expect(mailchimp_datum.reload.lists).to eq([])
            expect(mailchimp_datum.status).to eq "archived"
          end
        end
      end
      context "organization member" do
        let!(:organization_user) { FactoryBot.create(:organization_role_claimed, role: "member", user: user, organization: organization) }
        it "does not create" do
          expect(user.organizations.pluck(:id)).to eq([organization.id])
          mailchimp_datum = MailchimpDatum.find_or_create_for(user)
          expect(mailchimp_datum.lists).to eq([])
          expect(mailchimp_datum.status).to eq "no_subscription_required"
          expect(mailchimp_datum.id).to be_blank
          expect(UpdateMailchimpDatumWorker.jobs.count).to eq 0
        end
      end
      context "with feedback" do
        let!(:feedback) { FactoryBot.create(:feedback, user: user, kind: "lead_for_bike_shop") }
        it "creates and then finds for the user" do
          expect(feedback.reload.mailchimp_datum_id).to be_blank
          expect(user.feedbacks.pluck(:id)).to eq([feedback.id])
          mailchimp_datum = MailchimpDatum.find_or_create_for(user)
          expect(mailchimp_datum.lists).to eq(["organization"])
          expect(mailchimp_datum.subscribed?).to be_truthy
          expect(mailchimp_datum.id).to be_present
          expect(mailchimp_datum.user_id).to eq user.id
          expect(mailchimp_datum.feedbacks.pluck(:id)).to eq([feedback.id])
          expect(feedback.reload.mailchimp_datum_id).to eq mailchimp_datum.id
          expect(UpdateMailchimpDatumWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([mailchimp_datum.id])

          expect {
            mailchimp_datum.update(updated_at: Time.current)
          }.to_not change(UpdateMailchimpDatumWorker.jobs, :count)

          # And test that creating a membership doesn't result in update mailchimp datum
          FactoryBot.create(:organization_role_claimed, user: user, organization: organization)
          expect {
            mailchimp_datum.update(updated_at: Time.current)
          }.to_not change(UpdateMailchimpDatumWorker.jobs, :count)
        end
        it "also creates if passed the feedback" do
          expect(feedback.reload.mailchimp_datum_id).to be_blank
          expect(user.feedbacks.pluck(:id)).to eq([feedback.id])
          mailchimp_datum = MailchimpDatum.find_or_create_for(feedback)
          expect(mailchimp_datum.lists).to eq(["organization"])
          expect(mailchimp_datum.subscribed?).to be_truthy
          expect(mailchimp_datum.id).to be_present
          expect(mailchimp_datum.user_id).to eq user.id
          expect(mailchimp_datum.feedbacks.pluck(:id)).to eq([feedback.id])
          expect(feedback.reload.mailchimp_datum_id).to eq mailchimp_datum.id
          expect(UpdateMailchimpDatumWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([mailchimp_datum.id])

          expect {
            mailchimp_datum.update(updated_at: Time.current)
          }.to_not change(UpdateMailchimpDatumWorker.jobs, :count)
          # Thow this test in here too
          expect(MailchimpDatum.list("organization").pluck(:id)).to eq([mailchimp_datum.id])
          expect(MailchimpDatum.list("individual").pluck(:id)).to eq([])
          expect(MailchimpDatum.list("stuff").pluck(:id)).to eq([])
        end
      end
    end
    context "feedback" do
      let(:feedback) { FactoryBot.create(:feedback, kind: "message") }
      it "does not create" do
        mailchimp_datum = MailchimpDatum.find_or_create_for(feedback)
        expect(mailchimp_datum.lists).to eq([])
        expect(mailchimp_datum.no_subscription_required?).to be_truthy
        expect(mailchimp_datum.id).to be_blank
        expect(UpdateMailchimpDatumWorker.jobs.count).to eq 0
      end
      context "lead_for_school" do
        let!(:feedback) { FactoryBot.create(:feedback, kind: "lead_for_school") }
        let(:target) { empty_data.merge(lists: ["organization"], interests: ["school"]) }
        it "creates" do
          expect(feedback.reload.mailchimp_datum_id).to be_blank
          mailchimp_datum = MailchimpDatum.find_or_create_for(feedback)
          expect(mailchimp_datum.lists).to eq(["organization"])
          expect(mailchimp_datum.subscribed?).to be_truthy
          expect(mailchimp_datum.id).to be_present
          expect(mailchimp_datum.user_id).to be_blank
          expect(mailchimp_datum.feedbacks.pluck(:id)).to eq([feedback.id])
          expect(feedback.reload.mailchimp_datum_id).to eq mailchimp_datum.id
          expect(mailchimp_datum.data).to eq target.as_json
          expect(UpdateMailchimpDatumWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([mailchimp_datum.id])

          expect {
            mailchimp_datum.update(updated_at: Time.current)
          }.to_not change(UpdateMailchimpDatumWorker.jobs, :count)
        end
      end
    end
  end

  describe "calculated_lists" do
    it "is empty" do
      expect(MailchimpDatum.new.send(:calculated_lists)).to eq([])
    end
  end

  describe "calculated_data" do
    let(:mailchimp_datum) { MailchimpDatum.create(user: user) }
    context "empty" do
      let(:user) { User.new }
      it "is empty" do
        expect(mailchimp_datum.calculated_data.as_json).to eq empty_data.merge(tags: ["in_bike_index"]).as_json
      end
    end
    context "with organization admin" do
      let(:user) { FactoryBot.create(:organization_admin, organization: organization) }
      let(:target) { {lists: ["organization"], tags: %w[in_bike_index], interests: %w[bike_shop], merge_fields: target_merge_fields.reject { |_k, v| v.blank? }} }
      let(:target_merge_fields) do
        {
          organization_name: organization.name.to_s,
          organization_signed_up_at: organization.created_at.to_date&.to_s,
          bikes: 0,
          name: user.name,
          phone_number: user.phone,
          signed_up_at: user.created_at.to_date&.to_s,
          most_recent_donation_at: nil,
          number_of_donations: 0,
          recovered_bike_at: nil
        }
      end
      it "is as expected" do
        expect(user.reload.organization_roles.first.organization_creator?).to be_truthy
        expect(mailchimp_datum.calculated_data.as_json).to eq target.as_json
        expect(mailchimp_datum.managed_merge_fields.as_json).to eq target_merge_fields.as_json
        expect(mailchimp_datum.lists).to eq(["organization"])
      end
      context "not creator of organization" do
        let(:organization_kind) { "software" }
        it "is as expected" do
          expect(user).to be_present
          organization.update(pos_kind: "does_not_need_pos")
          expect(organization.reload.pos_kind).to eq "does_not_need_pos"
          # Doesn't include does_not_need_pos tag
          expect(mailchimp_datum.calculated_data.as_json).to eq target.merge(interests: ["software"]).as_json
          expect(mailchimp_datum.managed_merge_fields.as_json).to eq target_merge_fields.as_json
        end
      end
      context "ambassador" do
        let(:organization_kind) { "ambassador" }
        it "is no_subscription_required" do
          expect(user).to be_present
          expect(mailchimp_datum.mailchimp_organization_usership&.id).to be_blank
          # Doesn't include does_not_need_pos tag
          expect(mailchimp_datum.status).to eq "no_subscription_required"
          expect(mailchimp_datum.id).to be_blank
          expect(mailchimp_datum).to_not be_valid
          # And because I initially added some ambassador orgs, make sure we don't just load from the name
          mailchimp_datum.data["merge_fields"] = {organization_name: organization.name}
          expect(mailchimp_datum.mailchimp_organization_usership&.id).to be_blank
        end
      end
      context "lightspeed" do
        let!(:location) { FactoryBot.create(:location_chicago, organization: organization) }
        let(:lightspeed_merge_fields) do
          target_merge_fields.merge(organization_country: "US",
            organization_city: "Chicago",
            organization_state: "IL")
        end

        it "responds with lightspeed" do
          expect(location.reload&.state&.abbreviation).to eq "IL"
          organization.update(website: "test.com")
          expect(user).to be_present
          organization.update(pos_kind: "lightspeed_pos")
          expect(mailchimp_datum.calculated_data.as_json).to eq target.merge(tags: %w[in_bike_index lightspeed pos_approved]).as_json
          expect(mailchimp_datum.managed_merge_fields.as_json).to eq target_merge_fields.as_json
        end
      end
      context "ascend" do
        let!(:invoice) { FactoryBot.create(:invoice, organization: organization) }
        it "responds with lightspeed" do
          expect(user).to be_present
          organization.update(pos_kind: "ascend_pos")
          expect(organization.reload.paid?).to be_falsey
          expect(organization.invoices.count).to eq 1
          expect(mailchimp_datum.calculated_data.as_json).to eq target.merge(tags: %w[ascend in_bike_index pos_approved]).as_json
        end
      end
      context "not creator of organization" do
        let!(:organization_creator) { FactoryBot.create(:organization_admin, organization: organization) }
        it "is as expected" do
          expect(organization_creator.reload.organization_roles.first.organization_creator?).to be_truthy
          expect(user.reload.organization_roles.first.organization_creator?).to be_falsey
          expect(mailchimp_datum.calculated_data.as_json).to eq target.merge(tags: %w[in_bike_index not_org_creator]).as_json
        end
      end
      context "paid organization" do
        let!(:invoice) { FactoryBot.create(:invoice_paid, organization: organization) }
        it "returns paid" do
          organization.update(updated_at: Time.current)
          expect(organization.reload.paid?).to be_truthy
          expect(organization.paid_money?).to be_falsey
          expect(organization.paid_previously?).to be_falsey
          expect(mailchimp_datum.calculated_data.as_json).to eq target.merge(tags: %w[in_bike_index]).as_json
        end
      end
      context "paid_money organization" do
        let!(:invoice) { FactoryBot.create(:invoice_with_payment, organization: organization) }
        it "returns paid" do
          organization.update(updated_at: Time.current)
          expect(organization.reload.paid?).to be_truthy
          expect(organization.paid_money?).to be_truthy
          expect(organization.paid_previously?).to be_falsey
          expect(mailchimp_datum.calculated_data.as_json).to eq target.merge(tags: %w[in_bike_index paid]).as_json
        end
      end
      context "previously paid" do
        let!(:invoice) { FactoryBot.create(:invoice_with_payment, organization: organization, start_at: Time.current - 2.years) }
        it "returns paid_previously" do
          organization.reload
          expect(organization.paid?).to be_falsey
          expect(organization.paid_money?).to be_falsey
          expect(organization.paid_previously?).to be_truthy
          expect(invoice.reload.was_active?).to be_truthy
          expect(mailchimp_datum.calculated_data).to eq target.merge(tags: %w[in_bike_index paid_previously]).as_json
        end
      end
      context "individual list as well" do
        let(:payment_time) { Time.at(1621876049) }
        let(:payment) { FactoryBot.create(:payment, user: user, kind: "donation", created_at: payment_time) }
        let(:combined_merge_fields) { target_merge_fields.merge(most_recent_donation_at: payment_time.to_date.to_s, number_of_donations: 1) }
        it "is only organization list but includes the other interests" do
          payment.reload
          expect(user.reload.organization_roles.first.organization_creator?).to be_truthy
          expect(mailchimp_datum.managed_merge_fields.as_json).to eq combined_merge_fields.as_json
          expect(mailchimp_datum.lists).to eq(["organization"])
          target_combined = target.merge(interests: %w[bike_shop donors],
            merge_fields: combined_merge_fields.except(:recovered_bike_at, :phone_number))
          expect(mailchimp_datum.calculated_data.as_json).to eq target_combined.as_json
        end
      end
    end
    context "individual" do
      let(:user) { FactoryBot.create(:user) }
      let(:payment_time) { Time.at(1621876049) }
      let(:payment) { FactoryBot.create(:payment, user: user, kind: "donation", created_at: payment_time) }
      let(:target) { {lists: ["individual"], tags: %w[in_bike_index], interests: %w[donors], merge_fields: stored_merge_fields} }
      let(:stored_merge_fields) { {bikes: 0, name: user.name, signed_up_at: user.created_at.to_date&.to_s, most_recent_donation_at: payment_time.to_date.to_s, number_of_donations: 1} }
      let(:target_merge_fields) do
        {
          organization_name: nil,
          organization_signed_up_at: nil,
          bikes: 0,
          name: user.name,
          phone_number: user.phone,
          signed_up_at: user.created_at.to_date&.to_s,
          most_recent_donation_at: payment_time.to_date.to_s,
          number_of_donations: 1,
          recovered_bike_at: nil
        }
      end
      it "is as expected" do
        payment.reload
        expect(mailchimp_datum.calculated_data.as_json).to eq target.as_json
        expect(mailchimp_datum.managed_merge_fields.as_json).to eq target_merge_fields.as_json
        expect(mailchimp_datum.lists).to eq(["individual"])
      end
      context "recovered_bike_owner" do
        let(:bike) { FactoryBot.create(:bike, :with_stolen_record, :with_ownership_claimed, user: user) }
        let(:recovery_time) { Time.at(1592760319) }
        let(:target_recovered) { target.merge(interests: %w[recovered_bike_owners], merge_fields: target_merge_fields_recovered.reject { |_k, v| v.blank? }) }
        let(:we_helped) { true }
        before { bike.fetch_current_stolen_record.add_recovery_information(recovered_at: recovery_time.to_s, index_helped_recovery: we_helped) }
        let(:target_merge_fields_recovered) do
          target_merge_fields.merge(:most_recent_donation_at => nil, "bikes" => 1,
            :number_of_donations => 0, :recovered_bike_at => recovery_time.to_date.to_s)
        end
        it "is recovered and we helped" do
          expect(bike.reload.stolen_recovery?).to be_truthy
          expect(mailchimp_datum.stolen_records_recovered.pluck(:bike_id)).to eq([bike.id])
          expect(mailchimp_datum.calculated_data.as_json).to eq target_recovered.as_json
          expect(mailchimp_datum.managed_merge_fields.as_json).to eq target_merge_fields_recovered.as_json
        end
        context "both interests" do
          let(:target_both) { target_recovered.merge(interests: %w[donors recovered_bike_owners], merge_fields: target_merge_fields_both.reject { |_k, v| v.blank? }) }
          let(:target_merge_fields_both) { target_merge_fields.merge(recovered_bike_at: recovery_time.to_date.to_s, bikes: 1) }
          it "is both" do
            payment.reload
            expect(bike.reload.stolen_recovery?).to be_truthy
            expect(mailchimp_datum.stolen_records_recovered.pluck(:bike_id)).to eq([bike.id])
            expect(mailchimp_datum.calculated_data.as_json).to eq target_both.as_json
            expect(mailchimp_datum.managed_merge_fields.as_json).to eq target_merge_fields_both.as_json
          end
        end
        context "we didn't help" do
          let(:we_helped) { false }
          it "is recovered and we helped" do
            expect(bike.reload.stolen_recovery?).to be_truthy
            expect(mailchimp_datum.no_subscription_required?).to be_truthy
            expect(mailchimp_datum.stolen_records_recovered.pluck(:bike_id)).to eq([])
            expect(mailchimp_datum.id).to be_blank
          end
        end
      end
    end
  end

  describe "mailchimp_organization_usership" do
    let(:user) { FactoryBot.create(:organization_admin) }
    let(:organization1) { user.organizations.first }
    let(:organization_user2) { FactoryBot.create(:organization_role_claimed, user: user, role: "admin") }
    let(:organization2) { membership2.organization }
    let!(:mailchimp_datum) { MailchimpDatum.find_or_create_for(user) }
    it "uses the existing organization" do
      expect(mailchimp_datum).to be_valid
      expect(mailchimp_datum.mailchimp_organization&.id).to eq organization1.id
      mailchimp_datum.data["merge_fields"] = mailchimp_datum.managed_merge_fields
      mailchimp_datum.update(updated_at: Time.current)
      expect(membership2).to be_valid
      user.reload
      id = mailchimp_datum.id
      mailchimp_datum = MailchimpDatum.find(id) # Unmemoize
      expect(mailchimp_datum.mailchimp_organization&.id).to eq organization1.id
    end
  end

  describe "add_mailchimp_interests" do
    let(:mailchimp_datum) { MailchimpDatum.new(data: data) }
    let(:data) { {} }
    let(:interests) { {"938bcefe9e" => true, "d14183c940" => false} }
    it "adds interests" do
      mailchimp_datum.add_mailchimp_interests("individual", interests.as_json)
      expect(mailchimp_datum.interests).to eq(["938bcefe9e"])
      expect(mailchimp_datum.data).to eq({"interests" => ["938bcefe9e"]})
      expect(mailchimp_datum.mailchimp_interests("individual")).to eq({})
    end
    context "interests are in the system" do
      before do
        MailchimpValue.create!(kind: "interest", name: "Donor", mailchimp_id: "938bcefe9e", list: "individual")
        MailchimpValue.create!(kind: "interest", name: "Recovered bike owners", mailchimp_id: "d14183c940", list: "individual")
        MailchimpValue.create!(kind: "interest", name: "Bike Shop", mailchimp_id: "cbca7bf705", list: "organization")
      end
      it "adds the interests" do
        mailchimp_datum.add_mailchimp_interests("individual", interests.as_json)
        expect(mailchimp_datum.interests).to eq(["donor"])
        expect(mailchimp_datum.data).to eq({"interests" => ["donor"]})
        expect(mailchimp_datum.mailchimp_interests("individual")).to eq interests
      end
      context "existing interests" do
        let(:data) { {interests: ["Recovered bike owners"]} }
        it "adds the interests" do
          expect(mailchimp_datum.interests).to eq(["Recovered bike owners"])
          mailchimp_datum.add_mailchimp_interests("individual", interests.as_json)
          expect(mailchimp_datum.interests).to eq(["donor"])
          expect(mailchimp_datum.mailchimp_interests("individual")).to eq interests
        end
      end
      context "existing organization interests" do
        let(:data) { {interests: ["Donor", "Bike Shop"]} }
        it "adds the interests" do
          mailchimp_datum.add_mailchimp_interests("individual", interests.as_json)
          expect(mailchimp_datum.interests).to eq(["Bike Shop", "donor"])
          expect(mailchimp_datum.mailchimp_interests("individual")).to eq interests
        end
      end
    end
  end

  # NOTE: We don't actually use this right now. It's exclusively based on managed_merge_fields
  describe "add_mailchimp_merge_fields" do
    let(:mailchimp_datum) { MailchimpDatum.new(data: data) }
    let(:data) { {} }
    let(:merge_fields) { {"NAME" => "Party Pooper", "SIGN_UP_AT" => "2021-05-14", "BIKES" => 2} }
    it "adds merge_fields" do
      mailchimp_datum.add_mailchimp_merge_fields("individual", merge_fields.as_json)
      expect(mailchimp_datum.merge_fields).to eq merge_fields
      expect(mailchimp_datum.data).to eq({"merge_fields" => merge_fields})
      expect(mailchimp_datum.mailchimp_merge_fields("individual")).to eq({})
    end
    context "merge_fields are in the system" do
      before do
        MailchimpValue.create!(kind: "merge_field", name: "Name", mailchimp_id: "NAME", list: "individual")
        MailchimpValue.create!(kind: "merge_field", name: "Signed up at", mailchimp_id: "SIGN_UP_AT", list: "individual")
        MailchimpValue.create!(kind: "merge_field", name: "Bikes", mailchimp_id: "BIKES", list: "individual")
        MailchimpValue.create!(kind: "merge_field", name: "Signed up at", mailchimp_id: "SIGN_UP_AT", list: "organization")
        MailchimpValue.create!(kind: "merge_field", name: "Organization name", mailchimp_id: "O_NAME", list: "organization")
      end
      let(:stored_merge_fields) { {name: "Party Pooper", signed_up_at: "2021-05-14", bikes: 2} }
      it "adds the merge_fields" do
        mailchimp_datum.add_mailchimp_merge_fields("individual", merge_fields.as_json)
        expect(mailchimp_datum.merge_fields).to eq stored_merge_fields.as_json
        expect(mailchimp_datum.mailchimp_merge_fields("individual")).to eq({"BIKES" => 0})
      end
    end
  end

  describe "add_mailchimp_tags" do
    let(:mailchimp_datum) { MailchimpDatum.new(data: data) }
    let(:data) { {} }
    let(:tags) { [{id: 1892850, name: "Weird new tag"}, {id: 1889682, name: "In Bike Index"}] }
    it "adds new tags it doesn't know" do
      mailchimp_datum.add_mailchimp_tags("individual", tags.as_json)
      expect(mailchimp_datum.tags).to eq(["In Bike Index", "Weird new tag"])
      expect(mailchimp_datum.data).to eq({"tags" => ["In Bike Index", "Weird new tag"]})
      expect(mailchimp_datum.mailchimp_tags("individual")).to eq([])
    end
    context "tags are in the system" do
      before do
        MailchimpValue.create!(kind: "tag", name: "In Bike Index", mailchimp_id: "1889682", list: "individual")
        MailchimpValue.create!(kind: "tag", name: "Weird new tag", mailchimp_id: "1892850", list: "individual")
        MailchimpValue.create!(kind: "tag", name: "2020", mailchimp_id: "87330", list: "individual")
        MailchimpValue.create!(kind: "tag", name: "POS Approved", mailchimp_id: "87318", list: "organization")
      end
      it "adds the tags" do
        mailchimp_datum.add_mailchimp_tags("individual", tags.as_json)
        expect(mailchimp_datum.tags).to eq(["in_bike_index", "weird_new_tag"])
        expect(mailchimp_datum.data).to eq({"tags" => ["in_bike_index", "weird_new_tag"]})
        expect(mailchimp_datum.mailchimp_tags("individual")).to eq([{name: "In Bike Index", status: "active"}])
      end
      context "non-managed tags" do
        let(:tags) { [{id: 1892850, name: "Weird new tag"}, {id: 87330, name: "2020"}] }
        it "doesn't update anything" do
          mailchimp_datum.add_mailchimp_tags("individual", tags.as_json)
          expect(mailchimp_datum.tags).to eq(["2020", "weird_new_tag"])
          expect(mailchimp_datum.data).to eq({"tags" => ["2020", "weird_new_tag"]})
          expect(mailchimp_datum.mailchimp_tags("individual")).to eq([{name: "In Bike Index", status: "inactive"}])
        end
      end
      context "existing tags" do
        let(:data) { {tags: ["2020", "AND THIS TOO"]} }
        it "removes existing tags" do
          mailchimp_datum.add_mailchimp_tags("individual", tags.as_json)
          expect(mailchimp_datum.tags).to eq(["AND THIS TOO", "in_bike_index", "weird_new_tag"])
          expect(mailchimp_datum.mailchimp_tags("individual")).to eq([{name: "In Bike Index", status: "active"}])
        end
      end
      context "existing organization tags" do
        let(:data) { {tags: ["2020", "POS Approved", "in Bike Index"]} }
        let(:tags) { [{id: 1892850898888, name: "A different taggg"}, {id: 1889682, name: "In Bike Index"}] }
        it "doesn't remove them" do
          mailchimp_datum.add_mailchimp_tags("individual", tags.as_json)
          expect(mailchimp_datum.tags).to eq(["A different taggg", "POS Approved", "in_bike_index"])
          expect(mailchimp_datum.mailchimp_tags("individual")).to eq([{name: "In Bike Index", status: "active"}])
        end
      end
    end
  end
end
