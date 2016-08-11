require 'spec_helper'

describe MailerVariables do
  let(:subject) { MailerVariables.new(mailer_method) }
  describe 'var_hash' do
    context 'ownership_invitation_email' do
      let(:mailer_method) { 'ownership_invitation_email' }
      xit 'returns the hash that we want' do
        ownership = FactoryGirl.create(:ownership)
        target = {
          is_new_user: true,
          is_recovered_bike: false,
          is_stolen_bike: false,
          is_registered_by_owner: true,
          is_new_registration: true,
          bike_stolenness_display: 'stuff',
          creator_display_name: 'stuff',
          bike_display_background: 'blank',
          bike_display_text_color: 'stuff',
          bike_url: 'stuff',
          bike_thumb_url: 'stuff',
          bike_manufacturer: 'stuff',
          bike_serial: 'stuff',
          bike_paint_string: 'stuff'
        }
        result = subject.var_hash(ownership_id: ownership.id)
        pp result
        expect(result).to eq target
      end
    end
  end

  context 'internal method' do
    let(:mailer_method) { '' }

    describe 'ownership_hash' do
      let(:user) { FactoryGirl.create(:user) }
      let(:bike_target) do
        {
          is_new_registration: true,
          bike_type: bike.type,
          is_recovered_bike: false,
          is_stolen_bike: false,
          bike_url: "#{ENV['BASE_URL']}/ownerships/#{ownership.id}",
          bike_thumb_url: 'https://files.bikeindex.org/email_assets/bike_photo_placeholder.png',
          bike_manufacturer: bike.manufacturer_name,
          bike_serial: bike.serial,
          bike_paint_string: bike.primary_frame_color.name
        }
      end
      context 'new registration' do
        let(:bike) { FactoryGirl.create(:bike, owner_email: user.email, creator_id: user.id) }
        let(:ownership) { FactoryGirl.create(:ownership, user: user, bike: bike) }
        let(:target) do
          bike_target.merge(is_new_user: false, is_registered_by_owner: true)
        end
        it 'returns the ownership hash, includes and overrides for bike_hash' do
          expect(subject.ownership_hash(ownership.id)).to eq target
        end
      end
      context 'sending existing registration' do
        let(:bike) { FactoryGirl.create(:bike, owner_email: 'someotheremail@stuff.com', creator_id: user.id) }
        let(:ownership_1) { FactoryGirl.create(:ownership, user: user, bike: bike) }
        let(:ownership) { FactoryGirl.create(:ownership, bike: bike) }
        let(:target) do
          bike_target.merge(is_new_user: true, is_registered_by_owner: false, is_new_registration: false)
        end
        it 'returns correct hash' do
          expect(ownership_1).to be_present
          expect(subject.ownership_hash(ownership.id)).to eq target
        end
      end
    end

    describe 'bike_display_hash' do
      context 'no thumb' do
        let(:bike) { FactoryGirl.create(:stolen_bike) }
        let(:target) do
          {
            bike_type: bike.type,
            is_recovered_bike: false,
            is_stolen_bike: true,
            is_new_registration: true,
            bike_url: "#{ENV['BASE_URL']}/bikes/#{bike.id}",
            bike_thumb_url: 'https://files.bikeindex.org/email_assets/bike_photo_placeholder.png',
            bike_manufacturer: bike.manufacturer_name,
            bike_serial: bike.serial,
            bike_paint_string: bike.primary_frame_color.name
          }
        end
        it 'returns stolen with placeholder url' do
          expect(subject.bike_display_hash(bike)).to eq target
        end
      end
      context 'with stock_photo' do
        let(:bike) { FactoryGirl.create(:bike, stock_photo_url: 'https://bikeindex.org/fake_picture.png') }
        let(:target) do
          {
            bike_type: bike.type,
            is_recovered_bike: false,
            is_stolen_bike: false,
            is_new_registration: true,
            bike_url: "#{ENV['BASE_URL']}/bikes/#{bike.id}",
            bike_thumb_url: 'https://bikeindex.org/fake_picture.png',
            bike_manufacturer: bike.manufacturer.name,
            bike_serial: bike.serial,
            bike_paint_string: bike.frame_colors.to_sentence
          }
        end
        it 'returns non-stolen with the thumb url' do
          expect(subject.bike_display_hash(bike)).to eq target
        end
      end
    end

    describe 'bike_from_ownership' do
      it 'returns bike even if bike is hidden' do
        ownership = FactoryGirl.create(:ownership)
        bike = ownership.bike
        bike.update_attribute :hidden, true
        expect(subject.bike_from_ownership(ownership)).to eq bike
      end
    end
  end
end
