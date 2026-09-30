require "rails_helper"

RSpec.describe OrgServices::Signup do
  describe "permitted_step" do
    let(:organization_signup) { FactoryBot.create(:organization_signup) }

    it "is step 1 until step 1 is saved" do
      expect(described_class.permitted_step(organization_signup, "1")).to eq "1"
      expect(described_class.permitted_step(organization_signup, "2")).to eq "1"
      expect(described_class.permitted_step(organization_signup, nil)).to eq "1"
    end

    context "started" do
      let(:organization_signup) { FactoryBot.create(:organization_signup_started) }

      it "permits up to step 2" do
        expect(described_class.permitted_step(organization_signup, "1")).to eq "1"
        expect(described_class.permitted_step(organization_signup, "2")).to eq "2"
        expect(described_class.permitted_step(organization_signup, "finished")).to eq "2"
        expect(described_class.permitted_step(organization_signup, "party")).to eq "2"
      end
    end

    context "details completed" do
      let(:organization_signup) { FactoryBot.create(:organization_signup_details_completed) }

      it "permits every step, and goes to finished" do
        expect(described_class.permitted_step(organization_signup, "1")).to eq "1"
        expect(described_class.permitted_step(organization_signup, "2")).to eq "2"
        expect(described_class.permitted_step(organization_signup, nil)).to eq "finished"
      end
    end
  end

  describe "save_start" do
    let(:organization_signup) { FactoryBot.create(:organization_signup, email: nil) }
    let(:start_params) { {name: "Shifty Bike Shop", kind: "bike_shop", email: " Org_Admin@bikeindex.org"} }
    let(:user) { nil }
    let(:saved) { described_class.save_start(organization_signup, user:, **start_params) }

    it "saves" do
      expect(saved).to be_truthy
      expect(organization_signup.reload).to have_attributes(name: "Shifty Bike Shop", kind: "bike_shop",
        email: "org_admin@bikeindex.org", likely_spam: false)
    end

    context "missing everything" do
      let(:start_params) { {name: " ", kind: "ambassador", email: "not-an-email"} }

      it "doesn't save, with the errors" do
        expect(saved).to be_falsey
        expect(organization_signup.errors.full_messages).to match_array(["Organization name is required",
          "Please choose what kind of organization this is", "A valid email is required"])
        expect(organization_signup.reload.name).to be_nil
      end
    end

    context "a taken name" do
      let!(:organization) { FactoryBot.create(:organization, name: "Shifty Bike Shop") }

      it "doesn't save" do
        expect(saved).to be_falsey
        expect(organization_signup.errors.full_messages).to eq(["That name isn't available - please choose another"])
      end
    end

    context "a reserved name" do
      let(:start_params) { {name: "Registrations", kind: "bike_shop", email: "org_admin@bikeindex.org"} }

      it "doesn't save" do
        expect(saved).to be_falsey
        expect(organization_signup.errors.full_messages).to eq(["That name isn't available - please choose another"])
      end
    end

    context "signed in" do
      let(:user) { FactoryBot.create(:user_confirmed, email: "signed_in@bikeindex.org") }

      it "uses their email" do
        expect(saved).to be_truthy
        expect(organization_signup.reload.email).to eq "signed_in@bikeindex.org"
      end
    end

    context "the honeypot filled" do
      it "saves, flagged" do
        expect(described_class.save_start(organization_signup, user:, additional: "spam", **start_params)).to be_truthy
        expect(organization_signup.reload.likely_spam).to be_truthy
        expect(described_class.send_confirmation_email(organization_signup)).to be_falsey
      end
    end

    context "after the confirmation was sent" do
      let(:organization_signup) { FactoryBot.create(:organization_signup_started) }
      before { described_class.send_confirmation_email(organization_signup) }

      it "keeps the link for the same address, and replaces it for a new one" do
        token = organization_signup.reload.email_confirmation_token
        expect(token).to be_present
        expect(described_class.save_start(organization_signup, user:, **start_params, email: "org_admin@bikeindex.org")).to be_truthy
        expect(organization_signup.reload.email_confirmation_token).to eq token

        expect(saved).to be_truthy
        expect(described_class.save_start(organization_signup, user:, **start_params, email: "new@bikeindex.org")).to be_truthy
        expect(organization_signup.reload).to have_attributes(email_confirmation_token: nil, email_confirmation_sent_at: nil)
        expect { described_class.send_confirmation_email(organization_signup) }
          .to change(EmailJobs::OrganizationSignupConfirmationJob.jobs, :size).by 1
      end
    end
  end

  describe "save_details" do
    let(:organization_signup) { FactoryBot.create(:organization_signup_started) }
    let(:address) { {street: "10544 82 Ave NW", city: "Edmonton", postal_code: "T6E 2A4", country_id: Country.canada_id.to_s, region_string: "AB"} }
    let(:saved) do
      described_class.save_details(organization_signup, website: "shiftybikes.com", phone: "7183839999",
        publicly_visible: "0", address:)
    end

    it "saves, and completes the details" do
      expect(saved).to be_truthy
      expect(organization_signup.reload).to have_attributes(website: "shiftybikes.com", phone: "7183839999",
        publicly_visible: false, address: address.as_json)
      expect(organization_signup.details_completed?).to be_truthy
    end

    context "missing the street" do
      let(:address) { {city: "Edmonton", postal_code: "T6E 2A4", country_id: Country.canada_id.to_s} }

      it "saves what's there, without completing" do
        expect(saved).to be_falsey
        expect(organization_signup.errors.full_messages).to eq(["Please enter the organization's full address"])
        expect(organization_signup.reload.website).to eq "shiftybikes.com"
        expect(organization_signup.details_completed?).to be_falsey
      end
    end
  end

  describe "confirmation_token_valid?" do
    let(:organization_signup) { FactoryBot.create(:organization_signup_started) }
    before { described_class.send_confirmation_email(organization_signup) }

    it "is the token that was sent, until it's spent" do
      token = organization_signup.reload.email_confirmation_token
      expect(described_class.confirmation_token_valid?(organization_signup, "wrong")).to be_falsey
      expect(described_class.confirmation_token_valid?(organization_signup, token)).to be_truthy
      described_class.confirm_email!(organization_signup)
      expect(described_class.confirmation_token_valid?(organization_signup, token)).to be_falsey
      expect(organization_signup.reload.email_confirmed?).to be_truthy
    end

    it "rate limits resends" do
      expect { described_class.send_confirmation_email(organization_signup) }
        .to_not change(EmailJobs::OrganizationSignupConfirmationJob.jobs, :size)
    end
  end

  describe "complete" do
    let(:organization_signup) { FactoryBot.create(:organization_signup_details_completed) }
    let(:user) { FactoryBot.create(:user_confirmed, email: organization_signup.email) }

    it "creates the organization, its location and the admin" do
      organization = described_class.complete(organization_signup, user:)
      expect(organization).to be_persisted
      expect(organization).to have_attributes(name: "Shifty Bike Shop", kind: "bike_shop",
        website: "http://shiftybikes.com", auto_user_id: user.id, approved: true)
      expect(organization.locations.first).to have_attributes(name: "Shifty Bike Shop", phone: "7183839999",
        publicly_visible: true)
      expect(organization.locations.first.address_record)
        .to have_attributes(street: "10544 82 Ave NW", city: "Edmonton", country_id: Country.canada_id)
      expect(organization.organization_roles.pluck(:user_id, :role)).to eq([[user.id, "admin"]])
      expect(organization_signup.reload.organization_id).to eq organization.id
      expect(Feedback.last.feedback_type).to eq "organization_created"
    end

    context "the name was taken since step 1" do
      before { FactoryBot.create(:organization, name: "Shifty Bike Shop") }

      it "creates nothing" do
        organization = described_class.complete(organization_signup, user:)
        expect(organization).to_not be_persisted
        expect(organization.errors.full_messages.to_sentence).to match(/already in use/)
        expect(OrganizationRole.count).to eq 0
        expect(organization_signup.reload.organization_id).to be_nil
      end
    end
  end
end
