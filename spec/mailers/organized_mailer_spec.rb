require "rails_helper"

RSpec.describe OrganizedMailer, type: :mailer do
  let(:organization) { FactoryBot.create(:organization_with_auto_user) }
  let(:header_mail_snippet) do
    FactoryBot.create(:organization_mail_snippet,
                      kind: "header",
                      organization: organization,
                      body: "<p>HEADERXSNIPPET</p>")
  end
  describe "partial_registration" do
    context "without organization" do
      let(:b_param) { FactoryBot.create(:b_param_stolen) }
      it "stolen renders, with reply to for the organization" do
        expect(b_param.owner_email).to be_present
        mail = OrganizedMailer.partial_registration(b_param)
        expect(mail.subject).to eq("Finish your Bike Index registration!")
        expect(mail.to).to eq([b_param.owner_email])
        expect(mail.reply_to).to eq(["contact@bikeindex.org"])
      end
    end
    context "with organization" do
      let(:organization) { FactoryBot.create(:organization_with_auto_user) }
      context "non-stolen, organization has mail snippet" do
        let(:b_param) { FactoryBot.create(:b_param_with_creation_organization, organization: organization) }
        it "renders, with reply to for the organization" do
          expect(b_param.owner_email).to be_present
          expect(header_mail_snippet).to be_present
          organization.reload
          mail = OrganizedMailer.partial_registration(b_param)
          expect(mail.subject).to eq("Finish your #{organization.short_name} Bike Index registration!")
          expect(mail.to).to eq([b_param.owner_email])
          expect(mail.reply_to).to eq([organization.auto_user.email])
          expect(mail.body.encoded).to match header_mail_snippet.body
        end
        context "with partial snippet" do
          let!(:partial_mail_snippet) do
            FactoryBot.create(:organization_mail_snippet,
                              kind: "partial",
                              organization: organization,
                              body: "<p>PARTIALYXSNIPPET</p>")
          end
          it "includes mail snippet" do
            expect(b_param.owner_email).to be_present
            expect(header_mail_snippet).to be_present
            organization.reload
            mail = OrganizedMailer.partial_registration(b_param)
            expect(mail.subject).to eq("Finish your #{organization.short_name} Bike Index registration!")
            expect(mail.to).to eq([b_param.owner_email])
            expect(mail.reply_to).to eq([organization.auto_user.email])
            expect(mail.body.encoded).to match header_mail_snippet.body
            expect(mail.body.encoded).to match partial_mail_snippet.body
          end
        end
      end
    end
  end

  describe "finished_registration" do
    let(:mail) { OrganizedMailer.finished_registration(ownership) }
    context "passed new ownership" do
      let(:ownership) { FactoryBot.create(:ownership) }
      it "renders email" do
        expect(mail.subject).to match "Confirm your Bike Index registration"
      end
    end
    context "existing bike and ownership passed" do
      let(:user) { FactoryBot.create(:user) }
      let(:ownership) { FactoryBot.create(:ownership, bike: bike) }
      context "non-stolen, multi-ownership" do
        let(:ownership_1) { FactoryBot.create(:ownership, user: user, bike: bike) }
        let(:bike) { FactoryBot.create(:bike, owner_email: "someotheremail@stuff.com", creator_id: user.id) }
        it "renders email" do
          expect(ownership_1).to be_present
          expect(mail.subject).to eq("Confirm your Bike Index registration")
          expect(mail.reply_to).to eq(["contact@bikeindex.org"])
        end
      end
      context "claimed registration (e.g. self_made)" do
        let(:bike) { FactoryBot.create(:bike, creator_id: user.id) }
        it "renders email" do
          ownership.update_attribute :claimed, true
          ownership.reload
          expect(ownership.claimed).to be_truthy
          expect(mail.subject).to eq("Bike Index registration successful")
          expect(mail.reply_to).to eq(["contact@bikeindex.org"])
        end
      end
      context "stolen" do
        let(:country) { FactoryBot.create(:country) }
        let(:bike) { FactoryBot.create(:stolen_bike) }
        it "renders email with the stolen title" do
          expect(mail.subject).to eq("Confirm your stolen #{bike.type} on Bike Index")
          expect(mail.reply_to).to eq(["contact@bikeindex.org"])
          expect(mail.body.encoded).to match bike.current_stolen_record.find_or_create_recovery_link_token
        end
      end
    end
    context "organized snippets" do
      let(:welcome_mail_snippet) do
        FactoryBot.create(:organization_mail_snippet,
                          kind: "welcome",
                          organization: organization,
                          body: "<p>WELCOMEXSNIPPET</p>")
      end
      let(:security_mail_snippet) do
        FactoryBot.create(:organization_mail_snippet,
                          kind: "security",
                          organization: organization,
                          body: "<p>SECURITYXSNIPPET</p>")
      end
      let(:ownership) { FactoryBot.create(:ownership, bike: bike) }

      before do
        expect([header_mail_snippet, welcome_mail_snippet, security_mail_snippet]).to be_present
        expect(organization.mail_snippets.count).to eq 3
      end
      context "new non-stolen bike" do
        let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
        it "renders email and includes the snippets" do
          expect(ownership.bike.ownerships.count).to eq 1
          expect(mail.subject).to eq("Confirm your #{organization.short_name} Bike Index registration")
          expect(mail.body.encoded).to match header_mail_snippet.body
          expect(mail.body.encoded).to match welcome_mail_snippet.body
          expect(mail.body.encoded).to match security_mail_snippet.body
          expect(mail.reply_to).to eq([organization.auto_user.email])
        end
      end
      context "new stolen registration" do
        let(:bike) { FactoryBot.create(:stolen_bike, creation_organization: organization) }
        it "renders and includes the org name in the title" do
          expect(ownership.bike.ownerships.count).to eq 1
          expect(mail.body.encoded).to match header_mail_snippet.body
          expect(mail.body.encoded).to match welcome_mail_snippet.body
          expect(mail.body.encoded).to match security_mail_snippet.body
          expect(mail.subject).to eq("Confirm your #{organization.short_name} stolen #{bike.type} on Bike Index")
          expect(mail.reply_to).to eq([organization.auto_user.email])
        end
      end
      context "non-new (pre-existing ownership)" do
        let(:bike) { FactoryBot.create(:bike, creation_organization: organization) }
        let!(:pre_existing_ownership) { FactoryBot.create(:ownership, bike: bike, created_at: Time.current - 1.minute) }
        it "renders email and doesn't include the snippets or org name" do
          expect(ownership.bike.ownerships.count).to eq 2
          expect(bike.ownerships.first).to eq pre_existing_ownership
          expect(bike.current_ownership).to eq ownership
          expect(mail.body.encoded).to_not match header_mail_snippet.body
          expect(mail.body.encoded).to_not match welcome_mail_snippet.body
          expect(mail.body.encoded).to_not match security_mail_snippet.body
          expect(mail.subject).to eq("Confirm your Bike Index registration")
          expect(mail.reply_to).to eq(["contact@bikeindex.org"])
        end
      end
    end
  end

  describe "organization_invitation" do
    let(:membership) { FactoryBot.create(:membership, organization: organization) }
    let(:mail) { OrganizedMailer.organization_invitation(membership) }
    before { expect(header_mail_snippet).to be_present }
    it "renders email" do
      expect(mail.body.encoded).to match header_mail_snippet.body
      expect(mail.subject).to eq("Join #{organization.short_name} on Bike Index")
      expect(mail.reply_to).to eq([organization.auto_user.email])
    end
  end

  describe "parking_notification" do
    let(:parking_notification) { FactoryBot.create(:parking_notification_organized, organization: organization) }
    let(:mail) { OrganizedMailer.parking_notification(parking_notification) }
    let(:target_retrieval_link_url) { "parking_notification_retrieved=#{parking_notification.retrieval_link_token}" }
    before { expect(header_mail_snippet).to be_present }
    it "renders email" do
      expect(parking_notification.retrieval_link_token).to be_present
      expect(mail.body.encoded).to match header_mail_snippet.body
      expect(mail.body.encoded).to match "map" # includes location
      expect(mail.body.encoded).to match target_retrieval_link_url
      expect(mail.reply_to).to eq([parking_notification.reply_to_email])
    end
  end

  describe "graduated_notification" do
    let(:user) { FactoryBot.create(:user) }
    let!(:graduated_notification) { FactoryBot.create(:graduated_notification, :with_user, organization: organization, user: user) }
    let(:mail) { OrganizedMailer.graduated_notification(graduated_notification) }
    let(:target_remaining_link_url) { "graduated_notification_remaining=#{graduated_notification.marked_remaining_link_token}" }
    before { expect(header_mail_snippet).to be_present }
    it "renders email" do
      expect(graduated_notification.marked_remaining_link_token).to be_present
      expect(mail.body.encoded).to match header_mail_snippet.body
      expect(mail.body.encoded).to match target_remaining_link_url
      expect(mail.to).to eq([graduated_notification.email])
      expect(mail.reply_to).to eq([organization.auto_user.email])
      expect(mail.subject).to eq graduated_notification.subject
    end
  end

  describe "hot_sheet_notification" do
    let(:recipient) { FactoryBot.create(:organization_member, organization: organization) }
    let(:stolen_record) { FactoryBot.create(:stolen_record, :with_bike_image) }
    let(:bike) { stolen_record.bike }
    let(:hot_sheet) { FactoryBot.create(:hot_sheet, organization: organization, recipient_ids: [recipient.id, organization.auto_user.id], stolen_record_ids: [stolen_record.id]) }
    before { expect(header_mail_snippet).to be_present }
    let(:mail) { OrganizedMailer.hot_sheet(hot_sheet) }
    it "renders email" do
      # Sometimes, bikes end up without the most recent thumb path. We want to ensure that the
      bike.update_column :thumb_path, nil
      bike.reload
      expect(bike.public_images.count).to eq 1
      expect(bike.thumb_path).to be_blank
      expect(hot_sheet.fetch_recipients.pluck(:id)).to match_array([organization.auto_user.id, recipient.id])
      expect(mail.body.encoded).to match header_mail_snippet.body
      expect(mail.body.encoded).to match hot_sheet.subject
      expect(mail.body.encoded).to match bike_path(stolen_record.bike.to_param) # using path because we don't care about specifics
      expect(mail.to).to eq([organization.auto_user.email])
      expect(mail.reply_to).to eq([organization.auto_user.email])
      # It removes the auto_user from the bcc
      expect(mail.bcc).to eq([recipient.email])
      expect(mail.subject).to eq hot_sheet.subject
      # expect the bike to have a thumb_path
      bike.reload
      expect(bike.thumb_path).to be_present
    end
    context "passed in email" do
      let(:mail) { OrganizedMailer.hot_sheet(hot_sheet, ["seth@test.com"]) }
      it "sends to passed in email" do
        expect(mail.to).to eq(["seth@test.com"])
        expect(mail.reply_to).to eq([organization.auto_user.email])
        expect(mail.bcc).to eq([])
        expect(mail.subject).to eq hot_sheet.subject
      end
    end
  end
end
