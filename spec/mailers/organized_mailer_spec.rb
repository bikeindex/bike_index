require 'spec_helper'

describe OrganizedMailer do
  let(:organization) { FactoryGirl.create(:organization_with_auto_user) }
  let(:header_mail_snippet) do
    FactoryGirl.create(:organization_mail_snippet,
                       name: 'header',
                       organization: organization,
                       body: '<p>HEADERXSNIPPET</p>')
  end
  describe 'partial_registration' do
    context 'without organization' do
      let(:b_param) { FactoryGirl.create(:b_param_stolen) }
      it 'stolen renders, with reply to for the organization' do
        expect(b_param.owner_email).to be_present
        mail = OrganizedMailer.partial_registration(b_param)
        expect(mail.subject).to eq('Finish your Bike Index registration!')
        expect(mail.to).to eq([b_param.owner_email])
        expect(mail.reply_to).to eq(['contact@bikeindex.org'])
      end
    end
    context 'with organization' do
      let(:organization) { FactoryGirl.create(:organization_with_auto_user) }
      context 'non-stolen, organization has mail snippet' do
        let(:b_param) { FactoryGirl.create(:b_param_with_creation_organization, organization: organization) }
        it 'renders, with reply to for the organization' do
          expect(b_param.owner_email).to be_present
          expect(header_mail_snippet).to be_present
          organization.reload
          mail = OrganizedMailer.partial_registration(b_param)
          expect(mail.subject).to eq("Finish your #{organization.short_name} Bike Index registration!")
          expect(mail.to).to eq([b_param.owner_email])
          expect(mail.reply_to).to eq([organization.auto_user.email])
          expect(mail.body.encoded).to match header_mail_snippet.body
        end
      end
    end
  end

  describe 'finished_registration' do
    let(:mail) { OrganizedMailer.finished_registration(ownership) }
    context 'passed new ownership' do
      let(:ownership) { FactoryGirl.create(:ownership) }
      it 'renders email' do
        expect(mail.subject).to match 'Confirm your Bike Index registration'
      end
    end
    context 'existing bike and ownership passed' do
      let(:user) { FactoryGirl.create(:user) }
      let(:ownership) { FactoryGirl.create(:ownership, bike: bike) }
      context 'non-stolen, multi-ownership' do
        let(:ownership_1) { FactoryGirl.create(:ownership, user: user, bike: bike) }
        let(:bike) { FactoryGirl.create(:bike, owner_email: 'someotheremail@stuff.com', creator_id: user.id) }
        it 'renders email' do
          expect(ownership_1).to be_present
          expect(mail.subject).to eq('Confirm your Bike Index registration')
          expect(mail.reply_to).to eq(['contact@bikeindex.org'])
        end
      end
      context 'claimed registration (e.g. self_made)' do
        let(:bike) { FactoryGirl.create(:bike, creator_id: user.id) }
        it 'renders email' do
          ownership.update_attribute :claimed, true
          ownership.reload
          expect(ownership.claimed).to be_truthy
          expect(mail.subject).to eq('Bike Index registration successful')
          expect(mail.reply_to).to eq(['contact@bikeindex.org'])
        end
      end
      context 'stolen' do
        let(:cycle_type) { FactoryGirl.create(:cycle_type, name: 'sweet cycle type') }
        let(:country) { FactoryGirl.create(:country) }
        let(:bike) { FactoryGirl.create(:stolen_bike, cycle_type: cycle_type) }
        it 'renders email with the stolen title' do
          expect(mail.subject).to eq("Confirm your stolen #{cycle_type.name} on Bike Index")
          expect(mail.reply_to).to eq(['contact@bikeindex.org'])
          expect(mail.body.encoded).to match bike.current_stolen_record.find_or_create_recovery_link_token
        end
      end
    end
    context 'organized snippets' do
      let(:welcome_mail_snippet) do
        FactoryGirl.create(:organization_mail_snippet,
                           name: 'welcome',
                           organization: organization,
                           body: '<p>WELCOMEXSNIPPET</p>')
      end
      let(:security_mail_snippet) do
        FactoryGirl.create(:organization_mail_snippet,
                           name: 'security',
                           organization: organization,
                           body: '<p>SECURITYXSNIPPET</p>')
      end
      let(:ownership) { FactoryGirl.create(:ownership, bike: bike) }

      before do
        expect([header_mail_snippet, welcome_mail_snippet, security_mail_snippet]).to be_present
        expect(ownership.bike.ownerships.count).to eq 1
        expect(organization.mail_snippets.count).to eq 3
      end
      context 'new non-stolen bike' do
        let(:bike) { FactoryGirl.create(:organization_bike, creation_organization: organization) }
        it 'renders email and includes the snippets' do
          expect(mail.subject).to eq("Confirm your #{organization.short_name} Bike Index registration")
          expect(mail.body.encoded).to match header_mail_snippet.body
          expect(mail.body.encoded).to match welcome_mail_snippet.body
          expect(mail.body.encoded).to match security_mail_snippet.body
          expect(mail.reply_to).to eq([organization.auto_user.email])
        end
      end
      context 'new stolen registration' do
        let(:bike) { FactoryGirl.create(:stolen_bike, creation_organization: organization) }
        it 'renders and includes the org name in the title' do
          expect(mail.body.encoded).to match header_mail_snippet.body
          expect(mail.body.encoded).to match welcome_mail_snippet.body
          expect(mail.body.encoded).to match security_mail_snippet.body
          expect(mail.subject).to eq("Confirm your #{organization.short_name} stolen #{bike.type} on Bike Index")
          expect(mail.reply_to).to eq([organization.auto_user.email])
        end
      end
      context 'non-new (pre-existing ownership)' do
        let(:bike) { FactoryGirl.create(:bike, creation_organization: organization) }
        let(:pre_existing_ownership) { FactoryGirl.create(:ownership, bike: bike, created_at: Time.now - 1.minute) }
        before do
          expect(pre_existing_ownership).to be_present
        end
        it "renders email and doesn't include the snippets or org name" do
          expect(bike.ownerships.count).to eq 2
          expect(bike.ownerships.first).to eq pre_existing_ownership
          expect(bike.current_ownership).to eq ownership
          expect(mail.body.encoded).to_not match header_mail_snippet.body
          expect(mail.body.encoded).to_not match welcome_mail_snippet.body
          expect(mail.body.encoded).to_not match security_mail_snippet.body
          expect(mail.subject).to eq('Confirm your Bike Index registration')
          expect(mail.reply_to).to eq(['contact@bikeindex.org'])
        end
      end
    end
  end

  describe 'organization_invitation' do
    let(:organization_invitation) { FactoryGirl.create(:organization_invitation, organization: organization) }
    let(:mail) { OrganizedMailer.organization_invitation(organization_invitation) }
    before do
      expect(header_mail_snippet).to be_present
    end
    it 'renders email' do
      expect(mail.body.encoded).to match header_mail_snippet.body
      expect(mail.subject).to eq("Join #{organization.short_name} on Bike Index")
      expect(mail.reply_to).to eq([organization.auto_user.email])
    end
  end
end
