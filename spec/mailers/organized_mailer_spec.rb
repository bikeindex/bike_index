require 'spec_helper'

describe OrganizedMailer do
  let(:header_mail_snippet) do
    FactoryGirl.create(:organization_mail_snippet,
                       name: 'header',
                       organization: organization,
                       body: '<p>HEADERXSNIPPET</p>')
  end
  describe 'partial_registration' do
    context 'with organization' do
      let(:organization) { FactoryGirl.create(:organization_with_auto_user) }
      context 'stolen' do
        let(:b_param) { FactoryGirl.create(:b_param_stolen_with_creation_organization, organization: organization) }
        it 'renders, with reply to for the organization' do
          expect(b_param.owner_email).to be_present
          mail = OrganizedMailer.partial_registration(b_param)
          expect(mail.subject).to eq('Finish your Bike Index registration!')
          expect(mail.to).to eq([b_param.owner_email])
          expect(mail.reply_to).to eq([organization.auto_user.email])
        end
      end
      context 'non-stolen, organization has mail snippet' do
        let(:b_param) { FactoryGirl.create(:b_param_with_creation_organization, organization: organization) }
        it 'renders, with reply to for the organization' do
          expect(b_param.owner_email).to be_present
          expect(header_mail_snippet).to be_present
          organization.reload
          mail = OrganizedMailer.partial_registration(b_param)
          expect(mail.subject).to eq('Finish your Bike Index registration!')
          expect(mail.to).to eq([b_param.owner_email])
          expect(mail.reply_to).to eq([organization.auto_user.email])
          expect(mail.body.encoded).to match header_mail_snippet.body
        end
      end
    end
  end

  describe 'finished_registration' do
    context 'passed new ownership' do
      let(:ownership) { FactoryGirl.create(:ownership) }
      it 'renders email' do
        mail = OrganizedMailer.finished_registration(ownership)
        expect(mail.subject).to match 'Claim your bike on BikeIndex.org!'
      end
    end
    context 'existing bike and ownership passed' do
      let(:user) { FactoryGirl.create(:user) }
      let(:bike) { FactoryGirl.create(:bike, owner_email: 'someotheremail@stuff.com', creator_id: user.id) }
      let(:ownership_1) { FactoryGirl.create(:ownership, user: user, bike: bike) }
      let(:ownership) { FactoryGirl.create(:ownership, bike: bike) }
      it 'renders email' do
        expect(ownership_1).to be_present
        mail = OrganizedMailer.finished_registration(ownership)
        expect(mail.subject).to eq('Claim your bike on BikeIndex.org!')
      end
    end
    context 'organized snippets' do
      let(:organization) { FactoryGirl.create(:organization_with_auto_user) }
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
      let(:bike) { FactoryGirl.create(:organization_bike, creation_organization: organization) }

      before do
        expect([header_mail_snippet, welcome_mail_snippet, security_mail_snippet].count).to eq 3
      end
      context 'new bike' do
        let(:ownership) { FactoryGirl.create(:ownership, bike: bike) }
        it 'renders email and includes the snippets' do
          expect(ownership.bike.ownerships.count).to eq 1
          expect(organization.mail_snippets.count).to eq 3
          mail = OrganizedMailer.finished_registration(ownership)
          expect(mail.subject).to eq('Claim your bike on BikeIndex.org!')
          expect(mail.body.encoded).to match header_mail_snippet.body
          expect(mail.body.encoded).to match welcome_mail_snippet.body
          expect(mail.body.encoded).to match security_mail_snippet.body
        end
      end
    end
  end
end
