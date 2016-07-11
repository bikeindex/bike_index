require 'spec_helper'

describe OrganizedMailer do
  describe 'partial_registration_email' do
    context 'with organization' do
      let(:auto_user) { FactoryGirl.create(:organization_auto_user) }
      let(:organization) { auto_user.organizations.first }
      context 'stolen' do
        let(:b_param) { FactoryGirl.create(:b_param_stolen_with_creation_organization, organization: organization) }
        it 'sends a partial registration email, with reply to for the organization' do
          expect(b_param.owner_email).to be_present
          mail = OrganizedMailer.partial_registration_email(b_param)
          expect(mail.subject).to eq('Finish your Bike Index registration!')
          expect(mail.to).to eq([b_param.owner_email])
          expect(mail.reply_to).to eq([organization.auto_user.email])
        end
      end
      context 'non-stolen' do
        let(:b_param) { FactoryGirl.create(:b_param_with_creation_organization, organization: organization) }
        it 'sends a partial registration email, with reply to for the organization' do
          expect(b_param.owner_email).to be_present
          mail = OrganizedMailer.partial_registration_email(b_param)
          expect(mail.subject).to eq('Finish your Bike Index registration!')
          expect(mail.to).to eq([b_param.owner_email])
          expect(mail.reply_to).to eq([organization.auto_user.email])
        end
      end
    end
  end
end
