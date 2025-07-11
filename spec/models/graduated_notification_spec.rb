require "rails_helper"

RSpec.describe GraduatedNotification, type: :model do
  let(:graduated_notification_interval) { 3.days.to_i }
  let(:organization) do
    FactoryBot.create(:organization_with_organization_features,
      enabled_feature_slugs: ["graduated_notifications"],
      graduated_notification_interval: graduated_notification_interval)
  end
  describe "factories" do
    let(:graduated_notification) { FactoryBot.create(:graduated_notification, organization: organization) }
    let(:bike) { graduated_notification.bike }
    it "is valid" do
      expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
      expect(organization.deliver_graduated_notifications?).to be_truthy
      graduated_notification.reload
      expect(graduated_notification).to be_valid
      expect(bike.created_at).to be < (Time.current - graduated_notification_interval)
      expect(graduated_notification.send(:calculated_primary_notification).id).to eq graduated_notification.id
      expect(graduated_notification.send_email?).to be_truthy
      expect(graduated_notification.email_success?).to be_falsey
      expect {
        graduated_notification.process_notification
      }.to change(BikeOrganization, :count).by(-1)
      expect(bike.bike_organizations.pluck(:organization_id)).to eq([])
      graduated_notification.reload
      expect(graduated_notification.bike_organization.deleted?).to be_truthy
      expect(graduated_notification.email_success?).to be_truthy
      expect(graduated_notification.status).to eq "bike_graduated"
      expect(graduated_notification.status_humanized).to eq "bike graduated"
      expect(graduated_notification.processed?).to be_truthy
      expect(graduated_notification.user).to be_blank
      expect(graduated_notification.email).to eq bike.owner_email
      expect(graduated_notification.sent_at).to be_within(1).of graduated_notification.created_at + GraduatedNotification::PENDING_PERIOD
      expect(bike.graduated?(organization)).to be_truthy
    end
    context "organization doesn't have graduated_interval set" do
      let(:graduated_notification_interval) { nil }
      let(:graduated_notification2) { FactoryBot.create(:graduated_notification) }
      it "is valid" do
        graduated_notification.process_notification
        graduated_notification.reload
        expect(organization.deliver_graduated_notifications?).to be_falsey
        expect(graduated_notification).to be_valid
        expect(graduated_notification.bike_graduated?).to be_falsey
        expect(graduated_notification.processed?).to be_falsey
        expect(graduated_notification.user).to be_blank
        expect(graduated_notification.send_email?).to be_falsey
        expect(graduated_notification.email).to eq bike.owner_email
        expect(bike.graduated?(organization)).to be_falsey
        # Test setting graduated_notification_interval_days here, because this is where it matters
        expect(organization.graduated_notification_interval_days).to be_blank
        organization.update(graduated_notification_interval_days: "12")
        organization.reload
        expect(organization.graduated_notification_interval_days).to eq 12
        expect(organization.deliver_graduated_notifications?).to be_truthy
        organization.update(graduated_notification_interval_days: 0)
        organization.reload
        expect(organization.graduated_notification_interval_days).to be_blank
        expect(organization.deliver_graduated_notifications?).to be_falsey

        # Test scoping of graduated_notification bikes
        expect(graduated_notification2.bike_id).to_not eq bike.id
        expect(graduated_notification2.organization_id).to_not eq organization.id
        expect(GraduatedNotification.bikes.pluck(:id)).to match_array([bike.id, graduated_notification2.bike_id])
        expect(organization.graduated_notifications.bikes.pluck(:id)).to eq([bike.id])
      end
    end
    context "manually marked_remaining" do
      it "is not bike_graduated" do
        expect(graduated_notification.processed?).to be_falsey
        graduated_notification.process_notification
        graduated_notification.reload
        expect(graduated_notification.bike_organization.deleted?).to be_truthy
        bike_organization_id = graduated_notification.bike_organization.id
        expect(organization.bikes.pluck(:id)).to eq([])
        graduated_notification.mark_remaining!
        graduated_notification.reload
        expect(graduated_notification).to be_valid
        expect(graduated_notification.status).to eq "marked_remaining"
        expect(graduated_notification.status_humanized).to eq "marked not graduated"
        expect(graduated_notification.bike_graduated?).to be_falsey
        expect(graduated_notification.processed?).to be_truthy
        expect(graduated_notification.user).to be_blank
        expect(graduated_notification.send_email?).to be_truthy
        expect(graduated_notification.email).to eq bike.owner_email
        expect(bike.graduated?(organization)).to be_falsey
        expect(organization.bikes.pluck(:id)).to eq([bike.id])
        expect(graduated_notification.bike_organization.id).to eq bike_organization_id
      end
    end
    context "marked_remaining" do
      let(:graduated_notification) { FactoryBot.create(:graduated_notification, :marked_remaining, organization: organization, bike_created_at: Time.current - 1.year) }
      it "is not bike_graduated" do
        graduated_notification.reload
        expect(graduated_notification.bike_graduated?).to be_falsey
        expect(graduated_notification.processed?).to be_truthy
        expect(graduated_notification.email_success?).to be_truthy
        expect(graduated_notification.marked_remaining_at).to be < Time.current

        expect(BikeOrganization.unscoped.where(bike_id: bike.id).count).to eq 1
        bike_organization = BikeOrganization.unscoped.where(bike_id: bike.id).first
        expect(bike_organization.deleted?).to be_falsey

        bike.reload
        expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
        expect(bike.graduated?(organization)).to be_falsey
        expect(bike.organization_graduated_notifications(organization).pluck(:id)).to eq([graduated_notification.id])
      end
    end
  end

  describe "subject" do
    let(:graduated_notification) { FactoryBot.create(:graduated_notification) }
    let(:organization) { graduated_notification.organization }
    it "is default with snippet" do
      expect(graduated_notification.mail_snippet).to be_blank
      expect(graduated_notification.subject).to eq "Renew your bike registration with #{organization&.short_name}"
    end
    context "with mail_snippet" do
      let!(:mail_snippet) do
        FactoryBot.create(:mail_snippet,
          kind: "graduated_notification",
          subject: "Another crazy subject",
          organization: organization,
          is_enabled: true)
      end
      it "returns the mail_snippet" do
        expect(graduated_notification.mail_snippet).to eq mail_snippet
        expect(graduated_notification.subject).to eq "Another crazy subject"
      end
    end
  end

  describe "bikes_to_notify" do
    let(:graduated_notification_interval) { 2.years }
    let(:bike1) { FactoryBot.create(:bike_organized, creation_organization: organization, created_at: Time.current - 5.years) }
    let(:bike2) { FactoryBot.create(:bike_organized, :with_stolen_record, creation_organization: organization, created_at: Time.current - 3.years) }
    let!(:bike3) { FactoryBot.create(:bike_organized, :with_stolen_record, created_at: Time.current - 5.years) }
    let!(:bike_organization1) { bike1.bike_organizations.where(organization_id: organization.id).first }
    let!(:bike_organization2) { bike2.bike_organizations.where(organization_id: organization.id).first }
    let!(:graduated_notification1) { FactoryBot.create(:graduated_notification, :marked_remaining, bike: bike1, organization: organization) }
    it "finds bikes to notify" do
      bike1.reload
      expect(bike1.organization_graduated_notifications(organization).pluck(:id)).to eq([graduated_notification1.id])
      expect(bike3.organizations.pluck(:organization_id).count).to eq 1
      expect(bike3.organizations.pluck(:organization_id).first).to_not eq organization.id
      bike_organization1.reload
      bike_organization2.reload
      expect(bike_organization1.deleted?).to be_falsey
      expect(bike_organization2.deleted?).to be_falsey
      interval_start = Time.current - graduated_notification_interval
      expect(bike1.created_at).to be < interval_start - graduated_notification_interval # Double interval early
      expect(graduated_notification1.created_at).to be < interval_start
      expect(graduated_notification1.marked_remaining_at).to be < interval_start
      expect(GraduatedNotification.count).to eq 1
      expect(GraduatedNotification.bike_graduated.count).to eq 0
      expect(GraduatedNotification.bikes_to_notify_without_notifications(organization).pluck(:id)).to eq([bike2.id])
      expect(GraduatedNotification.bikes_to_notify_expired_notifications(organization).pluck(:id)).to match_array([bike1.id])
      expect(GraduatedNotification.bike_ids_to_notify(organization)).to match_array([bike1.id, bike2.id])
    end
  end

  describe "calculated_primary_bike" do
    before do
      bike2.current_ownership.update(created_at: Time.current - 6.months)
      bike1.current_ownership.update(created_at: Time.current - 1.year)
    end
    context "user" do
      let(:user) { FactoryBot.create(:user) }
      let(:bike1) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization, user: user) }
      let(:bike2) { FactoryBot.create(:bike_organized, :with_stolen_record, :with_ownership_claimed, creation_organization: organization, user: user) }
      it "finds the first bike" do
        _bike3 = FactoryBot.create(:bike_organized, :with_ownership, creation_organization: organization) # Test to ensure that we aren't grabbing bikes that aren't due notification
        expect(GraduatedNotification.bikes_to_notify_without_notifications(organization).pluck(:id)).to eq([bike1.id, bike2.id])
        expect(GraduatedNotification.bikes_to_notify_expired_notifications(organization).pluck(:id)).to match_array([])
        expect(GraduatedNotification.bike_ids_to_notify(organization)).to eq([bike1.id, bike2.id])
        expect(GraduatedNotification.count).to eq 0
        graduated_notification2 = GraduatedNotification.create(organization: organization, bike: bike2)
        graduated_notification2.update(created_at: Time.current - 1.day)
        expect(GraduatedNotification.count).to eq 1
        expect(graduated_notification2.primary_notification?).to be_falsey
        expect(graduated_notification2.user_id).to eq user.id
        graduated_notification2.reload
        expect(graduated_notification2.primary_bike?).to be_falsey
        expect(graduated_notification2.primary_bike).to eq bike1
        expect(graduated_notification2.send_email?).to be_falsey
        expect(graduated_notification2.processable?).to be_falsey
        expect(graduated_notification2.in_pending_period?).to be_falsey
        graduated_notification1 = GraduatedNotification.create(organization: organization, bike: bike1)
        graduated_notification1.update(created_at: Time.current - 1.day)
        expect(GraduatedNotification.count).to eq 2
        graduated_notification1.reload
        expect(graduated_notification1.primary_notification?).to be_truthy
        expect(graduated_notification1.primary_bike?).to be_truthy
        expect(graduated_notification1.primary_bike).to eq bike1
        expect(graduated_notification1.send_email?).to be_truthy
        expect(graduated_notification1.in_pending_period?).to be_falsey
        expect(graduated_notification1.processable?).to be_truthy
        expect(graduated_notification1.associated_bikes.pluck(:id)).to match_array([bike1.id, bike2.id])

        graduated_notification2.reload
        expect(graduated_notification2.primary_notification_id).to eq graduated_notification1.id
        expect(graduated_notification2.processable?).to be_falsey

        expect(GraduatedNotification.primary_notification.pluck(:id)).to eq([graduated_notification1.id])
        expect(GraduatedNotification.secondary_notification.pluck(:id)).to eq([graduated_notification2.id])

        expect(graduated_notification1.associated_notifications.pluck(:id)).to eq([graduated_notification2.id])
        # And test that we update to set the primary notification on the other one after creation
        graduated_notification2.reload
        expect(graduated_notification2.primary_notification?).to be_falsey

        # test that processing one processes them all
        expect(graduated_notification1.bike_organization.deleted?).to be_falsey
        expect(graduated_notification1.processed?).to be_falsey
        expect(graduated_notification2.bike_organization.deleted?).to be_falsey
        expect(graduated_notification2.processed?).to be_falsey
        expect {
          graduated_notification1.process_notification
        }.to change(ActionMailer::Base.deliveries, :count).by 1
        graduated_notification1.reload
        graduated_notification2.reload
        expect(graduated_notification1.bike_organization.deleted?).to be_truthy
        expect(graduated_notification1.processed?).to be_truthy
        expect(graduated_notification1.marked_remaining?).to be_falsey
        expect(graduated_notification2.bike_organization.deleted?).to be_truthy
        expect(graduated_notification2.processed?).to be_truthy
        expect(graduated_notification2.marked_remaining?).to be_falsey
        # Test that mark_remaining! one marks them all remaining
        graduated_notification1.mark_remaining!
        graduated_notification1.reload
        graduated_notification2.reload
        expect(graduated_notification1.bike_organization.deleted?).to be_falsey
        expect(graduated_notification1.processed?).to be_truthy
        expect(graduated_notification1.marked_remaining?).to be_truthy
        expect(graduated_notification2.bike_organization.deleted?).to be_falsey
        expect(graduated_notification2.processed?).to be_truthy
        expect(graduated_notification2.marked_remaining?).to be_truthy
      end
      context "multiple secondary created, without primary_notification_id" do
        let(:bike3) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: "test@example.edu") }
        let(:bike4) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: "test@example.edu") }
        before do
          bike4.current_ownership.update(created_at: Time.current - 13.months)
          bike3.current_ownership.update(created_at: Time.current - 14.months)
        end
        it "does not associate them" do
          expect(GraduatedNotification.bikes_to_notify_without_notifications(organization).pluck(:id)).to eq([bike3.id, bike4.id, bike1.id, bike2.id])
          # Notifications without primary_notification_id were being associated with each other (fixed in PR#1671)
          graduated_notification4 = GraduatedNotification.create(organization: organization, bike: bike4)
          graduated_notification2 = GraduatedNotification.create(organization: organization, bike: bike2)

          graduated_notification2.reload
          graduated_notification4.reload
          expect(graduated_notification2.primary_notification_id).to be_blank
          expect(graduated_notification4.primary_notification_id).to be_blank

          expect(GraduatedNotification.associated_notifications_including_self(graduated_notification2).pluck(:id)).to eq([graduated_notification2.id])
          expect(GraduatedNotification.associated_notifications_including_self(graduated_notification4).pluck(:id)).to eq([graduated_notification4.id])

          # ... creating the primary notifications fixes everything
          graduated_notification3 = GraduatedNotification.create(organization: organization, bike: bike3)
          graduated_notification1 = GraduatedNotification.create(organization: organization, bike: bike1)
          graduated_notification4.reload
          graduated_notification2.reload
          expect(graduated_notification4.primary_notification_id).to eq graduated_notification3.id
          expect(graduated_notification4.associated_notifications.pluck(:id)).to eq([graduated_notification3.id])
          expect(graduated_notification2.primary_notification_id).to eq graduated_notification1.id
          expect(graduated_notification2.associated_notifications.pluck(:id)).to eq([graduated_notification1.id])
        end
      end
    end
    context "not user" do
      let(:email) { "stuff@example.com" }
      let!(:bike1) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: email, created_at: Time.current - 52.weeks) }
      let!(:bike2) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: email, created_at: Time.current - 50.weeks) }
      let(:marked_remaining_at) { bike2.created_at - 3.weeks }
      it "finds the primary bike, outside of the interval" do
        bike1.reload
        expect(bike1.current_ownership.created_at).to be < Time.current - 51.weeks # Ensure factory sets ownership created_at
        Sidekiq::Job.clear_all
        ActionMailer::Base.deliveries = []
        graduated_notification1 = GraduatedNotification.create(organization: organization, bike: bike1)
        graduated_notification1.update(created_at: Time.current - 25.hours)
        expect(graduated_notification1.in_pending_period?).to be_falsey
        expect(graduated_notification1.processable?).to be_falsey
        expect(graduated_notification1.process_notification).to be_falsey
        expect(ActionMailer::Base.deliveries.count).to eq 0
        expect(organization.bikes.pluck(:id)).to match_array([bike1.id, bike2.id])
        expect(graduated_notification1.associated_notifications.pluck(:id)).to eq([])
        expect(graduated_notification1.primary_notification?).to be_truthy
        expect(graduated_notification1.primary_bike?).to be_truthy
        expect(graduated_notification1.primary_bike).to eq bike1
        expect(graduated_notification1.send_email?).to be_truthy
        expect(graduated_notification1.pending?).to be_truthy
        expect(graduated_notification1.associated_bikes.pluck(:id)).to match_array([bike1.id, bike2.id])

        graduated_notification2 = GraduatedNotification.create(organization: organization, bike: bike2)
        expect(graduated_notification2.in_pending_period?).to be_falsey
        expect(graduated_notification2.sent_at).to be_blank
        expect(graduated_notification2.processable?).to be_falsey
        expect(graduated_notification1.processable?).to be_truthy
        # Processing right now
        graduated_notification1.process_notification
        expect(ActionMailer::Base.deliveries.count).to eq 1
        graduated_notification1.reload
        expect(graduated_notification1.primary_bike?).to be_truthy
        expect(BikeOrganization.unscoped.find(graduated_notification1.bike_organization_id).deleted?).to be_truthy
        expect(graduated_notification1.user_id).to_not be_present
        expect(graduated_notification1.processed?).to be_truthy
        expect(graduated_notification1.associated_bikes.pluck(:id)).to match_array([bike1.id, bike2.id]) # Only finds this, the other is removed now
        expect(graduated_notification1.send(:calculated_primary_notification)&.id).to eq graduated_notification1.id
        expect(graduated_notification1.associated_notifications.pluck(:id)).to eq([graduated_notification2.id])

        graduated_notification2.reload
        expect(graduated_notification2.send_email?).to be_falsey
        expect(graduated_notification2.primary_notification?).to be_falsey
        expect(graduated_notification2.primary_bike?).to be_falsey
        expect(graduated_notification2.primary_bike_id).to eq bike1.id
        expect(graduated_notification2.send_email?).to be_falsey
        expect(graduated_notification2.processed_at).to be_present
        expect(graduated_notification2.processed?).to be_truthy
        expect(BikeOrganization.unscoped.find(graduated_notification2.bike_organization_id).deleted?).to be_truthy

        # And since we've sent these notifications, the bikes aren't around anymore
        expect(organization.bikes.pluck(:id)).to match_array([])
      end
    end
  end

  # This overlaps with some of the above tests, but it's separate to ensure coverage
  describe "bike assigned after creation" do
    let(:period_start) { Time.current - 8.days }
    let(:bike1) { FactoryBot.create(:bike_organized, :with_ownership_claimed, created_at: period_start, user: user, creation_organization: organization) }
    let(:user) { FactoryBot.create(:user) }
    let(:bike2) { FactoryBot.create(:bike_organized, :with_ownership_claimed, created_at: period_start + 4.days, user: user, creation_organization: organization) }
    it "it is still primary notification" do
      expect(bike1.user&.id).to eq user.id
      graduated_notification1 = GraduatedNotification.create(organization: organization, bike: bike1)
      graduated_notification1.update(created_at: Time.current - 1.day)
      expect(graduated_notification1.primary_notification?).to be_truthy
      expect(graduated_notification1.processable?).to be_truthy
      graduated_notification1.process_notification
      expect(graduated_notification1.primary_notification?).to be_truthy
      expect(graduated_notification1.email_success?).to be_truthy
      expect(graduated_notification1.processed?).to be_truthy
      expect(graduated_notification1.user_id).to eq user.id
      bike1.reload
      bike2.reload # This creates the bike
      expect(bike1.current_ownership.created_at).to be_within(100).of period_start
      expect(bike2.current_ownership.created_at).to be > bike1.current_ownership.created_at

      expect(bike2.user&.id).to eq user.id
      graduated_notification2 = GraduatedNotification.create(organization: organization, bike: bike2)
      expect(graduated_notification2.send(:potential_matching_period).cover?(graduated_notification1.created_at)).to be_truthy
      expect(graduated_notification2.send(:calculated_primary_notification).id).to eq graduated_notification1.id
      expect(graduated_notification2.send(:existing_sent_notification)&.id).to eq graduated_notification1.id
      expect(graduated_notification2.primary_notification_id).to eq graduated_notification1.id
      expect(graduated_notification2.primary_notification?).to be_falsey
      expect(graduated_notification2.primary_bike).to eq bike2
      expect(graduated_notification2.send_email?).to be_falsey

      # Ensure it's still the primary notification, even though it isn't the primary bike
      graduated_notification1.reload
      expect(graduated_notification1.send(:calculated_primary_notification).id).to eq graduated_notification1.id
      expect(graduated_notification1.associated_bikes.pluck(:id)).to match_array([bike1.id, bike2.id])
      expect(graduated_notification1.primary_notification?).to be_truthy
    end
  end

  describe "bike_organization recreated after graduated_notification sent" do
    let(:bike) { FactoryBot.create(:bike_organized, created_at: Time.current - 3 * graduated_notification_interval, creation_organization: organization) }
    let!(:bike_organization1) { bike.bike_organizations.where(organization_id: organization.id).first }
    let(:graduated_notification1) do
      expect(bike_organization1.deleted?).to be_falsey
      @bike_organization1_id = bike_organization1.id
      graduated_notification1 = GraduatedNotification.create(organization: organization, bike: bike, created_at: Time.current - graduated_notification_interval - 4.days)
      graduated_notification1.process_notification
      graduated_notification1.reload
      expect(graduated_notification1.processed?).to be_truthy
      graduated_notification1
    end
    it "marks the graduated_notification remaining, removes the more recent bike_organization" do
      expect(graduated_notification1.primary_notification?).to be_truthy
      expect(graduated_notification1.bike_organization.id).to eq @bike_organization1_id
      expect(BikeOrganization.unscoped.find(@bike_organization1_id).deleted?).to be_truthy
      graduated_notification1.mark_remaining!
      bike.reload
      expect(bike.bike_organizations.pluck(:id)).to eq([@bike_organization1_id])
    end
    context "another graduated_notification sent" do
      it "marks the more recent graduated_notification remaining as well" do
        expect(graduated_notification1.primary_notification?).to be_truthy
        expect(graduated_notification1.bike_organization.id).to eq @bike_organization1_id
        expect(BikeOrganization.unscoped.find(@bike_organization1_id).deleted?).to be_truthy
        expect(bike.organizations.pluck(:id)).to eq([])
        bike_organization_again = FactoryBot.create(:bike_organization, bike: bike, organization: organization, created_at: Time.current - 3.days)
        expect(bike_organization_again.valid?).to be_truthy
        graduated_notification1.reload
        expect(graduated_notification1.bike_organization.id).to eq @bike_organization1_id

        graduated_notification2 = GraduatedNotification.create(organization: organization, bike: bike, created_at: Time.current - 2.days)
        expect(graduated_notification2.errors.full_messages).to eq([])
        graduated_notification2.process_notification
        expect(graduated_notification2.bike_organization.id).to eq bike_organization_again.id
        expect(graduated_notification2.bike_organization.organization_id).to eq organization.id
        expect(graduated_notification2.bike_id).to eq graduated_notification1.bike_id
        bike_organization_again_id = graduated_notification2.bike_organization.id

        graduated_notification1.mark_remaining!
        graduated_notification1.reload
        graduated_notification2.reload
        bike_organization1.reload
        bike_organization_again.reload
        expect(graduated_notification1.marked_remaining?).to be_truthy
        expect(graduated_notification2.marked_remaining?).to be_truthy
        expect(BikeOrganization.unscoped.find(@bike_organization1_id).deleted?).to be_falsey
        expect(BikeOrganization.unscoped.find(bike_organization_again_id).deleted?).to be_truthy
      end
    end
  end

  describe "process_notification" do
    let(:graduated_notification_interval) { 2.years.to_i }
    let(:user) { FactoryBot.create(:user_confirmed) }
    let(:graduated_notification1) { FactoryBot.build(:graduated_notification, :with_user, organization: organization, user: user) }
    let!(:bike1) { graduated_notification1.bike }
    it "does not deliver or change anything if the organization doesn't have an interval" do
      graduated_notification1.save
      organization.update(graduated_notification_interval: nil)
      graduated_notification1.reload
      expect(graduated_notification1.processed?).to be_falsey
      expect(graduated_notification1.send_email?).to be_falsey
      Sidekiq::Job.clear_all
      ActionMailer::Base.deliveries = []
      expect(GraduatedNotification.count).to eq 1
      expect {
        expect(graduated_notification1.process_notification).to be_falsey
      }.to change(CreateGraduatedNotificationJob.jobs, :count).by 0
      graduated_notification1.reload
      expect(graduated_notification1.status).to eq "pending"
      expect(graduated_notification1.processed?).to be_falsey
      expect(graduated_notification1.send_email?).to be_falsey
    end
    context "user_registration_organization" do
      let(:user_registration_organization) { FactoryBot.create(:user_registration_organization, user: user, organization: organization, all_bikes: true) }
      it "removes all_bikes" do
        expect(user_registration_organization.reload.bikes.pluck(:id)).to eq([bike1.id])
        ::Callbacks::AfterUserChangeJob.new.perform(user.id)
        graduated_notification1.save
        expect(graduated_notification1.reload.user).to be_present
        expect(graduated_notification1.processed?).to be_falsey
        expect(graduated_notification1.send_email?).to be_truthy
        expect(graduated_notification1.user_registration_organization&.id).to eq user_registration_organization.id
        expect(bike1.reload.bike_organizations.count).to eq 1
        Sidekiq::Job.clear_all
        ActionMailer::Base.deliveries = []
        expect(GraduatedNotification.count).to eq 1
        expect {
          expect(graduated_notification1.process_notification).to be_truthy
        }.to change(CreateGraduatedNotificationJob.jobs, :count).by 0
        graduated_notification1.reload
        expect(graduated_notification1.status).to eq "bike_graduated"
        expect(graduated_notification1.processed?).to be_truthy
        expect(graduated_notification1.send_email?).to be_truthy
        Sidekiq::Testing.inline! do
          ::Callbacks::AfterUserChangeJob.new.perform(user.id)
        end
        expect(bike1.reload.bike_organizations.count).to eq 0
        expect(bike1.graduated?).to be_truthy
        expect(bike1.graduated?(organization)).to be_truthy
        expect(bike1.graduated?(Organization.new)).to be_falsey
        expect(UserRegistrationOrganization.count).to eq 0
        expect(graduated_notification1.user_registration_organization&.id).to eq user_registration_organization.id
        graduated_notification1.mark_remaining!
        Sidekiq::Testing.inline! do
          graduated_notification1.mark_remaining!
        end
        expect(bike1.reload.bike_organizations.count).to eq 1
        expect(UserRegistrationOrganization.count).to eq 1
        expect(UserRegistrationOrganization.unscoped.count).to eq 1
      end
      context "two bikes" do
        let!(:bike2) { FactoryBot.create(:bike_organized, :with_ownership_claimed, user: user, creation_organization: organization, created_at: bike1.created_at + 1.hour) }
        it "removes all_bikes" do
          expect(user_registration_organization.reload.bikes.pluck(:id)).to eq([bike1.id, bike2.id])
          ::Callbacks::AfterUserChangeJob.new.perform(user.id)
          graduated_notification1.save
          # Manually create graduated_notification2 because whateves
          graduated_notification2 = GraduatedNotification.create(bike_id: bike2.id, organization_id: organization.id)
          expect(graduated_notification1.reload.user).to be_present
          expect(graduated_notification1.processed?).to be_falsey
          expect(graduated_notification1.primary_notification?).to be_truthy
          expect(graduated_notification1.send_email?).to be_truthy
          expect(graduated_notification1.user_registration_organization&.id).to eq user_registration_organization.id
          expect(graduated_notification2.reload.primary_notification?).to be_falsey
          expect(graduated_notification2.user_registration_organization&.id).to eq user_registration_organization.id
          expect(bike1.reload.bike_organizations.count).to eq 1
          expect(bike2.reload.bike_organizations.count).to eq 1
          Sidekiq::Job.clear_all
          ActionMailer::Base.deliveries = []
          expect(GraduatedNotification.count).to eq 2
          Sidekiq::Testing.inline! do
            expect(graduated_notification1.process_notification).to be_truthy
          end
          graduated_notification1.reload
          expect(graduated_notification1.status).to eq "bike_graduated"
          expect(graduated_notification1.processed?).to be_truthy
          expect(graduated_notification1.send_email?).to be_truthy
          # This was failing, fixed in #2346
          expect(bike1.reload.bike_organizations.count).to eq 0
          expect(bike1.graduated?(organization)).to be_truthy
          expect(bike2.reload.bike_organizations.count).to eq 0
          expect(bike2.graduated?(organization)).to be_truthy
          expect(UserRegistrationOrganization.count).to eq 0
          expect(graduated_notification1.user_registration_organization&.id).to eq user_registration_organization.id
          graduated_notification1.mark_remaining!
          Sidekiq::Testing.inline! do
            graduated_notification1.mark_remaining!
          end
          expect(bike1.reload.bike_organizations.count).to eq 1
          expect(bike1.graduated?(organization)).to be_falsey
          expect(bike2.reload.bike_organizations.count).to eq 1
          expect(bike2.graduated?(organization)).to be_falsey
          expect(UserRegistrationOrganization.count).to eq 1
          expect(UserRegistrationOrganization.unscoped.count).to eq 1
        end
      end
    end
    context "bike created inside of notification interval" do
      let!(:bike2) { FactoryBot.create(:bike_organized, :with_ownership_claimed, user: user, creation_organization: organization, created_at: Time.current - 1.hour) }
      let(:interval_start) { Time.current - graduated_notification_interval }
      it "enqueues additional graduated_notification creation if they aren't there" do
        expect(bike1.created_at).to be < interval_start
        expect(bike2.created_at).to be > interval_start
        expect(bike1.user&.id).to eq user.id
        expect(bike2.user&.id).to eq user.id
        expect(GraduatedNotification.bike_ids_to_notify(organization)).to eq([bike1.id])
        # Actually store the graduated notification in the database, ensure it's out of the pending period
        graduated_notification1.update(created_at: Time.current - 2.days)
        expect(graduated_notification1.in_pending_period?).to be_falsey
        expect(GraduatedNotification.bike_ids_to_notify(organization)).to eq([])
        Sidekiq::Job.clear_all
        ActionMailer::Base.deliveries = []
        expect(graduated_notification1.associated_bikes.pluck(:id)).to match_array([bike1.id, bike2.id])
        expect {
          expect(graduated_notification1.process_notification).to be_falsey
        }.to change(CreateGraduatedNotificationJob.jobs, :count).by 1
        expect(ActionMailer::Base.deliveries.count).to eq 0
        expect(CreateGraduatedNotificationJob.jobs.map { |j| j["args"] }.flatten).to eq([organization.id, bike2.id])
        expect(graduated_notification1.associated_bikes.pluck(:id)).to match_array([bike1.id, bike2.id])
        expect(graduated_notification1.send(:associated_bike_ids_missing_notifications)).to eq([bike2.id])

        expect(GraduatedNotification.count).to eq 1
        expect {
          CreateGraduatedNotificationJob.drain
        }.to change(GraduatedNotification, :count).by 1
        expect(ActionMailer::Base.deliveries.count).to eq 0
        graduated_notification2 = GraduatedNotification.reorder(:created_at).last
        expect(graduated_notification2.bike_id).to eq bike2.id
        expect(graduated_notification2.primary_notification_id).to eq graduated_notification1.id
        expect(graduated_notification2.primary_bike_id).to eq bike1.id
        expect(graduated_notification2.email).to eq bike1.owner_email
        expect(graduated_notification2.user_id).to eq user.id
        expect(graduated_notification2.status).to eq "pending"
        expect(graduated_notification2.processed?).to be_falsey
        expect(graduated_notification1.user_registration_organization&.id).to be_blank
        expect(bike1.reload.bike_organizations.count).to eq 1
        expect(bike2.reload.bike_organizations.count).to eq 1

        graduated_notification1.process_notification
        expect(ActionMailer::Base.deliveries.count).to eq 1
        graduated_notification1.reload
        expect(graduated_notification1.processed?).to be_truthy
        expect(graduated_notification1.bike_graduated?).to be_truthy
        graduated_notification2.reload
        expect(graduated_notification2.processed?).to be_truthy
        expect(graduated_notification2.bike_graduated?).to be_truthy
        expect(bike1.reload.bike_organizations.count).to eq 0
        expect(bike2.reload.bike_organizations.count).to eq 0

        # And then we create another bike after the notification has been processed - it's no longer added in there
        _bike3 = FactoryBot.create(:bike_organized, :with_ownership_claimed, user: user, creation_organization: organization)
        graduated_notification1.reload
        graduated_notification2.reload
        expect(graduated_notification1.associated_bikes.pluck(:id)).to match_array([bike1.id, bike2.id])
        expect(graduated_notification2.associated_bikes.pluck(:id)).to match_array([bike1.id, bike2.id])
      end
    end
  end

  describe "mark_previous_notifications_not_most_recent" do
    let!(:graduated_notification) { FactoryBot.create(:graduated_notification, :marked_remaining, organization: organization) }
    let(:bike) { graduated_notification.bike }
    let(:graduated_notification2) { FactoryBot.create(:graduated_notification, bike: bike, organization: organization) }
    it "matches and updates" do
      expect(graduated_notification.reload.most_recent?).to be_truthy

      expect(graduated_notification2.reload.most_recent?).to be_truthy

      expect(graduated_notification2.send(:previous_notifications).pluck(:id)).to eq([graduated_notification.id])

      expect(graduated_notification.send(:previous_notifications).pluck(:id)).to eq([])
      expect(graduated_notification.reload.most_recent?).to be_falsey
    end
    context "non-primary" do
      let!(:bike2) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: bike.owner_email, created_at: Time.current - 2.years) }
      let(:graduated_notification2) { FactoryBot.create(:graduated_notification, organization: organization, bike: bike2, created_at: graduated_notification.created_at + 1.day) }
      it "updates it too" do
        expect(graduated_notification.reload.most_recent?).to be_truthy
        expect(graduated_notification.user_id).to be_blank

        expect(graduated_notification2.user_id).to be_blank
        expect(graduated_notification2.email).to eq graduated_notification.email
        expect(graduated_notification2.reload.most_recent?).to be_truthy
        expect(graduated_notification2.send(:existing_sent_notification)&.id).to eq graduated_notification.id
        expect(graduated_notification2.primary_notification_id).to eq graduated_notification.id
        expect(graduated_notification2.primary_notification?).to be_falsey

        expect(graduated_notification.reload.primary_notification?).to be_truthy
        expect(graduated_notification.primary_notification_id).to eq graduated_notification.id

        graduated_notification3 = GraduatedNotification.create(bike: bike2, organization: organization)
        expect(graduated_notification3.reload.most_recent?).to be_truthy
        expect(graduated_notification3.primary_notification?).to be_falsey
        expect(graduated_notification3.associated_bikes.map(&:id).sort).to eq([bike.id, bike2.id])

        expect(graduated_notification.reload.most_recent?).to be_truthy
        expect(graduated_notification.most_recent_graduated_notification&.id).to eq graduated_notification.id
        expect(graduated_notification.associated_bikes.map(&:id).sort).to eq([bike.id, bike2.id])
        expect(graduated_notification2.reload.most_recent?).to be_falsey
        expect(graduated_notification2.most_recent_graduated_notification&.id).to eq graduated_notification3.id
        expect(graduated_notification2.associated_bikes.map(&:id).sort).to eq([bike.id, bike2.id])
      end
    end
    context "different org" do
      let(:organization2) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["graduated_notifications"], graduated_notification_interval: graduated_notification_interval) }
      let!(:bike_organization2) { FactoryBot.create(:bike_organization, organization: organization2, bike: bike, created_at: Time.current - 1.year) }
      it "doesn't match" do
        expect(graduated_notification.reload.most_recent?).to be_truthy
        expect(graduated_notification.status).to eq "marked_remaining"

        expect(bike.bike_organizations.pluck(:organization_id)).to match_array([organization.id, organization2.id])
        graduated_notification3 = GraduatedNotification.create(bike: bike, organization: organization2)
        expect(graduated_notification3).to be_valid
        expect(graduated_notification3.primary_notification_id).to eq graduated_notification3.id
        allow(graduated_notification3).to receive(:processable?) { true }
        expect(graduated_notification3.process_notification).to be_truthy
        expect(graduated_notification3.reload.most_recent?).to be_truthy
        expect(graduated_notification3.status).to eq "bike_graduated"
        expect(graduated_notification3.associated_notifications.pluck(:id)).to eq([])

        expect(graduated_notification.reload.most_recent?).to be_truthy
      end
    end
    context "bike owner changes" do
      let(:user2) { FactoryBot.create(:user_confirmed) }
      it "doesn't update" do
        expect(graduated_notification.reload.most_recent?).to be_truthy
        expect(graduated_notification.user_id).to be_blank

        expect(bike.ownerships.count).to eq 1
        BikeServices::Updator.new(bike: bike, user: user2, permitted_params: {bike: {owner_email: user2.email}}.as_json).update_ownership
        expect(bike.reload.owner_email).to eq user2.email
        expect(bike.user.id).to eq user2.id
        expect(bike.ownerships.count).to eq 2
        expect(bike.bike_organizations.pluck(:organization_id)).to eq([organization.id])
        expect(graduated_notification.reload.user_id).to be_blank
        expect(graduated_notification.email).to_not eq user2.email

        graduated_notification2 = GraduatedNotification.create(bike: bike, organization: organization)
        expect(graduated_notification2).to be_valid
        graduated_notification2.update_attribute :created_at, Time.current - 25.hours # Pending period
        expect(graduated_notification2).to be_valid
        expect(graduated_notification2.user_id).to eq user2.id
        expect(graduated_notification2.email).to eq user2.email
        expect(graduated_notification2.primary_bike_id).to eq bike.id

        expect(graduated_notification2.send(:existing_sent_notification)&.id).to be_blank
        expect(graduated_notification2.primary_notification?).to be_truthy
        expect(graduated_notification2.processable?).to be_truthy
        graduated_notification2.process_notification
        expect(graduated_notification2.reload.most_recent?).to be_truthy
        expect(graduated_notification2.status).to eq "bike_graduated"
        expect(graduated_notification2.send(:existing_sent_notification)&.id).to eq graduated_notification2.id

        expect(graduated_notification.reload.most_recent?).to be_truthy
      end
    end
  end
end
