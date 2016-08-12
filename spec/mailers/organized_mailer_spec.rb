require 'spec_helper'

describe OrganizedMailer do
  describe 'partial_registration' do
    context 'with organization' do
      let(:auto_user) { FactoryGirl.create(:organization_auto_user) }
      let(:organization) { auto_user.organizations.first }
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
      context 'non-stolen' do
        let(:b_param) { FactoryGirl.create(:b_param_with_creation_organization, organization: organization) }
        it 'renders, with reply to for the organization' do
          expect(b_param.owner_email).to be_present
          mail = OrganizedMailer.partial_registration(b_param)
          expect(mail.subject).to eq('Finish your Bike Index registration!')
          expect(mail.to).to eq([b_param.owner_email])
          expect(mail.reply_to).to eq([organization.auto_user.email])
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
  end
end
