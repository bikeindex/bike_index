require "rails_helper"

RSpec.describe OrganizedMailer, type: :mailer do
  let(:organization) { FactoryBot.create(:organization_with_auto_user) }
  let(:header_mail_snippet) do
    FactoryBot.create(:organization_mail_snippet,
      kind: "header",
      organization: organization,
      body: "<p>HEADERXSNIPPET</p>")
  end
  let(:variable_snippet) do
    FactoryBot.create(:organization_mail_snippet,
      kind: variable_snippet_kind,
      organization: organization,
      body: "<p>#{variable_snippet_kind}-snippet</p>")
  end

  def expect_render_donation(should_render, mail)
    snippet_to_match = "make a donation"
    if should_render
      expect(mail.body.encoded).to match snippet_to_match
    else
      expect(mail.body.encoded).to_not match snippet_to_match
    end
  end

  def expect_render_supporters(should_render, mail)
    snippet_to_match = "supported by"
    if should_render
      expect(mail.body.encoded).to match snippet_to_match
    else
      expect(mail.body.encoded).to_not match snippet_to_match
    end
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
        expect(mail.tag).to eq "partial_registration"
        expect_render_donation(true, mail)
        expect_render_supporters(true, mail)
      end
    end
    context "with organization" do
      let(:organization) { FactoryBot.create(:organization_with_auto_user) }
      context "non-stolen, organization has mail snippet" do
        let(:b_param) { FactoryBot.create(:b_param_with_creation_organization, organization: organization) }
        it "renders, with reply to for the organization" do
          expect(b_param.owner_email).to be_present
          expect(header_mail_snippet).to be_present
          expect(organization.reload.paid_money?).to be_falsey
          mail = OrganizedMailer.partial_registration(b_param)
          expect(mail.subject).to eq("Finish your #{organization.short_name} Bike Index registration!")
          expect(mail.to).to eq([b_param.owner_email])
          expect(mail.reply_to).to eq([organization.auto_user.email])
          expect(mail.body.encoded).to match header_mail_snippet.body
          expect(mail.tag).to eq "partial_registration"
          expect_render_donation(true, mail)
          expect_render_supporters(true, mail)
        end
        context "with partial snippet and paid invoice" do
          let!(:partial_mail_snippet) do
            FactoryBot.create(:organization_mail_snippet,
              kind: "partial_registration",
              organization: organization,
              body: "<p>PARTIALYXSNIPPET</p>")
          end
          let(:organization) { FactoryBot.create(:organization_with_organization_features, :with_auto_user) }
          let!(:invoice2) { FactoryBot.create(:invoice_with_payment, organization: organization) }
          it "includes mail snippet" do
            expect(b_param.owner_email).to be_present
            expect(header_mail_snippet).to be_present
            expect(organization.reload.paid_money?).to be_truthy
            mail = OrganizedMailer.partial_registration(b_param)
            expect(mail.subject).to eq("Finish your #{organization.short_name} Bike Index registration!")
            expect(mail.to).to eq([b_param.owner_email])
            expect(mail.reply_to).to eq([organization.auto_user.email])
            expect(mail.body.encoded).to match header_mail_snippet.body
            expect(mail.body.encoded).to match partial_mail_snippet.body
            expect(mail.tag).to eq "partial_registration"
            expect_render_donation(false, mail)
            expect_render_supporters(false, mail)
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
        expect(mail.tag).to eq "finished_registration"
        expect_render_donation(true, mail)
        expect_render_supporters(true, mail)
      end
    end
    context "existing bike and ownership passed" do
      let(:user) { FactoryBot.create(:user) }
      let(:ownership) { FactoryBot.create(:ownership, bike: bike) }
      context "non-stolen, multi-ownership" do
        let(:ownership1) { FactoryBot.create(:ownership, user: user, bike: bike) }
        let(:bike) { FactoryBot.create(:bike, owner_email: "someotheremail@stuff.com", creator_id: user.id) }
        it "renders email" do
          expect(ownership1).to be_present
          expect(mail.subject).to eq("Confirm your Bike Index registration")
          expect(mail.reply_to).to eq(["contact@bikeindex.org"])
          expect(mail.tag).to eq "finished_registration"
          expect_render_donation(true, mail)
          expect_render_supporters(true, mail)
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
          expect(mail.tag).to eq "finished_registration"
          expect_render_donation(true, mail)
          expect_render_supporters(true, mail)
        end
      end
      context "pos registration" do
        let(:organization) { FactoryBot.create(:organization, kind: "bike_shop") }
        let(:bike) { FactoryBot.create(:bike_lightspeed_pos, creation_organization: organization) }
        let(:ownership) { bike.current_ownership }
        it "renders email" do
          expect(bike.reload.current_ownership.new_registration?).to be_truthy
          expect(bike.current_ownership.organization_pre_registration?).to be_falsey
          expect(bike.creation_organization.kind).to eq "bike_shop"
          expect(bike.pos?).to be_truthy
          expect(mail.subject).to eq("Confirm your #{bike.creation_organization.name} Bike Index registration")
          expect(mail.reply_to).to eq(["contact@bikeindex.org"])
          expect(mail.tag).to eq "finished_registration_pos"
          expect_render_donation(true, mail)
          expect_render_supporters(false, mail)
          # But for a transferred registration, it does different
          ownership2 = FactoryBot.create(:ownership, bike: bike)
          expect(bike.reload.current_ownership.id).to eq ownership2.id
          expect(bike.pos?).to be_falsey
          expect(ownership2.reload.new_registration?).to be_falsey
          expect(ownership2.organization_pre_registration?).to be_falsey
          expect(ownership2.organization_id).to be_blank
          mail2 = OrganizedMailer.finished_registration(ownership2)
          expect(mail2.subject).to eq("Confirm your Bike Index registration")
          expect(mail2.reply_to).to eq(["contact@bikeindex.org"])
          expect(mail2.tag).to eq "finished_registration"
          expect_render_donation(true, mail2)
          expect_render_supporters(true, mail2)
        end
      end
      context "organization_pre_registration" do
        let(:user) { FactoryBot.create(:user_confirmed) }
        let(:organization) { FactoryBot.create(:organization, :with_auto_user, kind: "bike_shop", user: user) }
        let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, owner_email: user.email, creator: user) }
        let(:ownership) { bike.ownerships.first }
        it "renders email" do
          expect(bike.reload.creation_organization.kind).to eq "bike_shop"
          expect(bike.pos?).to be_falsey
          expect(ownership.reload.new_registration?).to be_truthy
          expect(ownership.organization_pre_registration?).to be_truthy
          expect(ownership.send_email).to be_truthy
          expect(mail.subject).to eq("#{bike.creation_organization.name} Bike Index registration successful")
          expect(mail.reply_to).to eq([user.email])
          expect(mail.tag).to eq "finished_registration"
          expect_render_donation(true, mail)
          expect_render_supporters(false, mail)
          # Transferred registration
          BikeUpdator.new(user: user, bike: bike, b_params: {bike: {owner_email: "new@bikes.com"}}.as_json).update_available_attributes
          AfterBikeSaveWorker.new.perform(bike.id, true, true)
          ownership2 = bike.reload.current_ownership
          expect(ownership2.id).to_not eq ownership.id
          expect(ownership.reload.current).to be_falsey
          expect(bike.pos?).to be_falsey
          expect(bike.owner_email).to eq "new@bikes.com"
          expect(ownership2.reload.new_registration?).to be_truthy
          expect(ownership2.owner_email).to eq "new@bikes.com"
          expect(ownership2.organization_pre_registration?).to be_falsey
          expect(ownership2.organization_id).to eq organization.id

          mail2 = OrganizedMailer.finished_registration(ownership2)
          expect(mail2.subject).to eq("Confirm your #{bike.creation_organization.name} Bike Index registration")
          expect(mail2.reply_to).to eq([user.email])
          expect(mail2.tag).to eq "finished_registration"
          # Doesn't render supporters
          expect_render_donation(true, mail2)
          expect_render_supporters(false, mail2)
        end
      end
      context "Organization registration" do
        let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
        let(:organization) { FactoryBot.create(:organization, :with_auto_user, kind: "bike_advocacy") }
        let(:ownership) { bike.current_ownership }
        it "renders email" do
          expect(bike.reload.current_ownership.organization&.id).to eq organization.id
          expect(bike.pos?).to be_falsey
          expect(mail.subject).to eq("Confirm your #{bike.creation_organization.name} Bike Index registration")
          expect(mail.reply_to).to eq([organization.auto_user&.email])
          expect(mail.tag).to eq "finished_registration"
          expect_render_donation(true, mail)
          expect_render_supporters(true, mail)
        end
        context "Bike shop" do
          let(:organization) { FactoryBot.create(:organization, :with_auto_user, kind: "bike_shop") }
          it "renders without supporters" do
            expect(bike.reload.current_ownership.organization&.id).to eq organization.id
            expect(mail.subject).to eq("Confirm your #{bike.creation_organization.name} Bike Index registration")
            expect(mail.reply_to).to eq([organization.auto_user&.email])
            expect(mail.tag).to eq "finished_registration"
            expect_render_donation(true, mail)
            expect_render_supporters(false, mail)
          end
        end
      end
      context "stolen" do
        let(:country) { FactoryBot.create(:country) }
        let(:bike) { FactoryBot.create(:stolen_bike) }
        it "renders email with the stolen title" do
          expect(mail.subject).to eq("Confirm your stolen #{bike.type} on Bike Index")
          expect(mail.reply_to).to eq(["contact@bikeindex.org"])
          expect(mail.body.encoded).to match bike.current_stolen_record.find_or_create_recovery_link_token
          expect(mail.tag).to eq "finished_registration"
          expect_render_donation(true, mail)
          expect_render_supporters(true, mail)
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
      let!(:ownership) { bike.ownerships.first }
      before do
        expect([header_mail_snippet, welcome_mail_snippet, security_mail_snippet]).to be_present
        expect(organization.mail_snippets.count).to eq 3
      end
      context "new non-stolen bike" do
        let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
        it "renders email and includes the snippets" do
          expect(bike.reload.ownerships.count).to eq 1
          expect(mail.subject).to eq("Confirm your #{organization.short_name} Bike Index registration")
          expect(mail.body.encoded).to match header_mail_snippet.body
          expect(mail.body.encoded).to match welcome_mail_snippet.body
          expect(mail.body.encoded).to match security_mail_snippet.body
          expect(mail.reply_to).to eq([organization.auto_user.email])
          expect(mail.tag).to eq "finished_registration"
        end
      end
      context "new stolen registration" do
        let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership, creation_organization: organization) }
        it "renders and includes the org name in the title" do
          expect(bike.reload.ownerships.count).to eq 1
          expect(mail.body.encoded).to match header_mail_snippet.body
          expect(mail.body.encoded).to match welcome_mail_snippet.body
          expect(mail.body.encoded).to match security_mail_snippet.body
          expect(mail.subject).to eq("Confirm your #{organization.short_name} stolen #{bike.type} on Bike Index")
          expect(mail.reply_to).to eq([organization.auto_user.email])
          expect(mail.tag).to eq "finished_registration"
        end
      end
      context "non-new (pre-existing ownership)" do
        let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization) }
        let(:previous_ownership) { bike.ownerships.first }
        let!(:ownership) { FactoryBot.create(:ownership, bike: bike) }
        it "renders email and doesn't include the snippets or org name" do
          expect(bike.reload.ownerships.count).to eq 2
          expect(bike.ownerships.first).to eq previous_ownership
          expect(previous_ownership.reload.current).to be_falsey
          expect(previous_ownership.organization_pre_registration).to be_falsey
          expect(bike.current_ownership).to eq ownership
          expect(ownership.reload.new_registration?).to be_falsey
          expect(ownership.organization).to be_blank
          expect(mail.body.encoded).to_not match header_mail_snippet.body
          expect(mail.body.encoded).to_not match welcome_mail_snippet.body
          expect(mail.body.encoded).to_not match security_mail_snippet.body
          expect(mail.subject).to eq("Confirm your Bike Index registration")
          expect(mail.reply_to).to eq(["contact@bikeindex.org"])
          expect(mail.tag).to eq "finished_registration"
        end
      end
    end
  end

  describe "organization_invitation" do
    let(:organization_role) { FactoryBot.create(:organization_role, organization: organization) }
    let(:mail) { OrganizedMailer.organization_invitation(organization_role) }
    before { expect(header_mail_snippet).to be_present }
    it "renders email" do
      expect(mail.body.encoded).to match header_mail_snippet.body
      expect(mail.subject).to eq("Join #{organization.short_name} on Bike Index")
      expect(mail.reply_to).to eq([organization.auto_user.email])
      expect(mail.tag).to eq "organization_invitation"
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
      expect(mail.body.encoded).to match "I picked up my"
      expect(mail.body.encoded).to match target_retrieval_link_url
      expect(mail.reply_to).to eq([parking_notification.reply_to_email])
      expect(mail.tag).to eq "parking_notification"
    end
    context "impound" do
      let(:parking_notification) { FactoryBot.create(:parking_notification_organized, organization: organization, kind: "impound_notification") }
      it "renders email, doesn't include retrieval link" do
        expect(parking_notification.retrieval_link_token).to_not be_present
        expect(mail.body.encoded).to match header_mail_snippet.body
        expect(mail.body.encoded).to match "map" # includes location
        expect(mail.body.encoded).to_not match "I picked up my"
        expect(mail.reply_to).to eq([parking_notification.reply_to_email])
      end
      context "impound_configuration email" do
        let!(:impound_configuration) { FactoryBot.create(:impound_configuration, email: "example@email.com", organization: organization) }
        it "renders email" do
          expect(parking_notification.retrieval_link_token).to_not be_present
          expect(mail.body.encoded).to match header_mail_snippet.body
          expect(mail.body.encoded).to match "map" # includes location
          expect(mail.reply_to).to eq(["example@email.com"])
        end
      end
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
    context "with graduated_notification snippet" do
      let(:variable_snippet_kind) { "graduated_notification" }
      before { expect(variable_snippet).to be_present }
      it "renders email" do
        expect(graduated_notification.marked_remaining_link_token).to be_present
        expect(mail.body.encoded).to match header_mail_snippet.body
        expect(mail.body.encoded).to match variable_snippet.body
        expect(mail.to).to eq([graduated_notification.email])
        expect(mail.reply_to).to eq([organization.auto_user.email])
        expect(mail.subject).to eq graduated_notification.subject
        expect(mail.tag).to eq "graduated_notification"
      end
    end
  end

  describe "hot_sheet_notification" do
    let(:recipient) { FactoryBot.create(:organization_user, organization: organization) }
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

  describe "impound_claim" do
    let(:impound_claim) { FactoryBot.create(:impound_claim, status: status, organization: organization) }
    let(:status) { "submitting" }
    describe "impound_claim_submitted" do
      let(:mail) { OrganizedMailer.impound_claim_submitted(impound_claim) }
      it "renders" do
        expect(impound_claim.reload.status).to eq status
        expect(mail.to).to eq([organization.auto_user.email])
        expect(mail.reply_to).to eq(["contact@bikeindex.org"])
        expect(mail.bcc).to be_blank
        expect(mail.subject).to eq "New impound claim submitted"
      end
      context "impound_configuration" do
        let!(:impound_configuration) { FactoryBot.create(:impound_configuration, email: "example@email.com", organization: organization) }
        it "renders" do
          expect(impound_claim.reload.status).to eq status
          expect(mail.to).to eq(["example@email.com"])
          expect(mail.reply_to).to eq(["contact@bikeindex.org"])
          expect(mail.bcc).to be_blank
          expect(mail.subject).to eq "New impound claim submitted"
        end
      end
    end

    describe "impound_claim_approved_or_denied" do
      let(:mail) { OrganizedMailer.impound_claim_approved_or_denied(impound_claim) }
      let(:status) { "approved" }
      let(:variable_snippet_kind) { "impound_claim_denied" }
      before { expect(variable_snippet).to be_present }
      it "renders" do
        expect(impound_claim.reload.status).to eq status
        organization.reload
        expect(mail.to).to eq([impound_claim.user.email])
        expect(mail.reply_to).to eq([organization.auto_user.email])
        expect(mail.bcc).to be_blank
        expect(mail.subject).to eq "Your impound claim was approved"
        expect(mail.body.encoded).to_not match variable_snippet.body
      end
      context "denied" do
        let(:status) { "denied" }
        it "renders" do
          expect(impound_claim.reload.status).to eq status
          organization.reload
          expect(mail.to).to eq([impound_claim.user.email])
          expect(mail.reply_to).to eq([organization.auto_user.email])
          expect(mail.bcc).to be_blank
          expect(mail.subject).to eq "Your impound claim was denied"
          expect(mail.body.encoded).to match variable_snippet.body
        end
      end
      context "impound_configuration and snippet" do
        let(:variable_snippet_kind) { "impound_claim_approved" }
        let!(:impound_configuration) { FactoryBot.create(:impound_configuration, email: "example@email.com", organization: organization) }
        it "renders" do
          expect(impound_claim.reload.status).to eq status
          organization.reload
          expect(mail.to).to eq([impound_claim.user.email])
          expect(mail.reply_to).to eq(["example@email.com"])
          expect(mail.bcc).to be_blank
          expect(mail.subject).to eq "Your impound claim was approved"
          expect(mail.body.encoded).to match variable_snippet.body
        end
      end
    end
  end
end
