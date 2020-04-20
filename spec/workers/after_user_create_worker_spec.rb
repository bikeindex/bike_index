require "rails_helper"

RSpec.describe AfterUserCreateWorker, type: :job do
  let(:subject) { AfterUserCreateWorker }
  let(:instance) { subject.new }

  let!(:user) { FactoryBot.create(:user, email: "owner1@A.COM") }
  let(:email) { user.email }

  before { Sidekiq::Worker.clear_all }

  describe "perform" do
    context "stage: new" do
      let(:user) { User.new(id: 69, email: "owner@jess.com") }
      it "sends confirmation email" do
        expect(instance).to receive(:associate_membership_invites).and_return(true)
        expect do
          instance.perform(user.id, "new", user: user)
        end.to change(AfterUserCreateWorker.jobs, :count).by 1
        expect(EmailConfirmationWorker.jobs.map { |j| j["args"] }.flatten).to eq([user.id])
        expect(AfterUserCreateWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([user.id, "async"])
      end

      context "confirmed user" do
        it "sends welcome email" do
          allow(user).to receive(:confirmed?) { true }
          expect do
            instance.perform(user.id, "new", user: user)
          end.to change(AfterUserCreateWorker.jobs, :count).by 1
          expect(EmailWelcomeWorker.jobs.map { |j| j["args"] }.flatten).to eq([user.id])
          expect(AfterUserCreateWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([user.id, "async"])
        end
      end
    end

    context "stage: confirmed" do
      it "associates" do
        expect(UserEmail).to receive(:create_confirmed_primary_email).with(user)
        expect do
          instance.perform(user.id, "confirmed", user: user)
        end.to change(AfterUserCreateWorker.jobs, :count).by 1
        expect(AfterUserCreateWorker.jobs.map { |j| j["args"] }.last.flatten).to eq([user.id, "async"])
      end
    end

    context "stage: merged" do
      it "associates" do
        expect(instance).to receive(:associate_ownerships)
        expect(instance).to receive(:associate_membership_invites)
        expect do
          instance.perform(user.id, "merged", user: user)
        end.to_not change(AfterUserCreateWorker.jobs, :count)
      end
    end

    context "stage: async" do
      it "calls import" do
        expect(instance).to_not receive(:associate_ownerships)
        expect(instance).to receive(:import_user_attributes)
        expect do
          instance.perform(user.id, "async")
        end.to_not change(AfterUserCreateWorker.jobs, :count)
      end
      context "confirmed user" do
        let(:user) { FactoryBot.create(:user_confirmed) }
        it "calls import and associate_ownerships" do
          expect(instance).to receive(:associate_ownerships)
          expect(instance).to receive(:import_user_attributes)
          expect do
            instance.perform(user.id, "async")
          end.to_not change(AfterUserCreateWorker.jobs, :count)
        end
      end
    end
  end

  describe "associate_ownerships" do
    let(:bike) { FactoryBot.create(:bike, owner_email: "owner1@a.com") }
    let!(:ownership) { FactoryBot.create(:ownership, owner_email: "OWner1@a.com", bike: bike) }
    let(:bike2) { FactoryBot.create(:bike, owner_email: "owner1@a.com") }
    let!(:ownership2) { FactoryBot.create(:ownership, owner_email: "owner1@a.com", bike: bike2) }
    let(:bike3) { FactoryBot.create(:bike, owner_email: "owner1@a.com") }
    let!(:ownership3) { FactoryBot.create(:ownership, owner_email: "owner1@a.com", bike: bike3) }

    it "assigns any ownerships that match the user email" do
      expect(user).to be_present
      ownerships = [ownership, ownership2, ownership3]
      ownerships.each { |o| expect(o.user).to be_nil }
      instance.associate_ownerships(user, email)

      ownerships.each do |o|
        o.reload
        expect(o.user).to eq user
      end
    end
  end

  context "extra user attributes" do
    # Block traditional run, so we can do it separately }
    before { allow_any_instance_of(User).to receive(:perform_create_jobs) { true } }
    let(:user) { FactoryBot.create(:user, email: "aftercreate@bikeindex.org") }
    let!(:state) { FactoryBot.create(:state, name: "California", abbreviation: "CA") }
    let!(:country) { Country.united_states }
    let!(:b_param) do
      FactoryBot.create(:b_param,
                        created_bike_id: bike.id,
                        creator: bike.creator,
                        params: { bike: { address: "Pier 15 The Embarcadero, 94111", phone: "(111) 222-3333" } })
    end
    let(:ownership) { FactoryBot.create(:ownership, user: user, owner_email: "aftercreate@bikeindex.org") }
    let(:target_address_hash) { { street: "Pier 15, The Embarcadero", city: "San Francisco", state: "CA", zipcode: "94111", country: "USA", latitude: 37.8016649, longitude: -122.397348 } }
    let!(:bike) { ownership.bike }
    include_context :geocoder_real
    it "assigns the extra user attributes" do
      VCR.use_cassette("after_user_create_worker-import_user_attributes") do
        expect(user).to be_present

        Sidekiq::Testing.inline! { instance.perform(user.id, "new") }
        ownership.reload
        user.reload
        bike.reload
        expect(b_param.fetch_formatted_address).to eq target_address_hash.as_json

        expect(user.phone).to eq "1112223333"
        expect(user.address_hash).to eq target_address_hash.as_json
        expect([user.to_coordinates]).to eq([37.8016649, -122.397348])
      end
    end
    context "existing attributes" do
      let(:user) { FactoryBot.create(:user, email: "aftercreate@bikeindex.org", phone: "929292", zipcode: "89999", skip_geocoding: true) }
      it "doesn't import" do
        instance.perform(user.id, "new")
        user.reload
        expect(user.phone).to eq "929292"
        expect(user.street).to be_nil
        expect(user.city).to be_nil
        expect(user.zipcode).to eq "89999"
        expect(user.state).to be_nil
        expect(user.country).to be_nil
      end
    end
  end

  describe "associate_membership_invites" do
    it "assigns any memberships that match the user email, and mark user confirmed if invited" do
      user = FactoryBot.build(:user, email: "owner1@B.COM")
      membership1 = FactoryBot.create(:membership, invited_email: " #{user.email.upcase}")
      membership2 = FactoryBot.create(:membership, invited_email: " #{user.email.upcase}")
      expect(membership1.claimed?).to be_falsey

      Sidekiq::Testing.inline! { user.save }

      expect(membership1.created_at < user.created_at).to be_truthy
      # This is called on create, so we just test that things happen correctly here
      expect(user.confirmed?).to be_truthy
      expect(membership1.reload.claimed?).to be_truthy
      expect(membership2.reload.claimed?).to be_truthy
      expect(membership1.user).to eq user
      expect(user.memberships.count).to eq 2
      expect(user.organizations.count).to eq 2
    end

    # We are processing the first organization inline so we can
    # redirect users to the organization they belong to
    it "synchronously associates the first memberhsip" do
      user = FactoryBot.build(:user, email: "owner1@B.COM")
      membership1 = FactoryBot.create(:membership, invited_email: " #{user.email.upcase}")
      membership2 = FactoryBot.create(:membership, invited_email: " #{user.email.upcase}")
      expect(membership1).to_not be_claimed
      expect(membership2).to_not be_claimed

      user.save

      expect(membership1.reload.created_at).to be < user.created_at
      expect(user).to be_confirmed
      expect(membership1).to be_claimed
      expect(membership1.user).to eq user
      expect(user.memberships.count).to eq(1)
      expect(user.organizations.count).to eq(1)
    end
  end

  describe "send_welcoming_email" do
    let(:user) { User.new(id: 69) }
    it "enques enqueues confirmation email" do
      instance.send_welcoming_email(user)
      expect(EmailConfirmationWorker).to have_enqueued_sidekiq_job(69)
    end
    context "confirmed user" do
      it "enques welcome email" do
        allow(user).to receive(:confirmed?) { true }
        instance.send_welcoming_email(user)
        expect(EmailWelcomeWorker.jobs.map { |j| j["args"] }.flatten).to eq([user.id])
      end
    end
  end
end
