require 'spec_helper'

describe Integration do
  describe 'validations' do
    it { is_expected.to validate_presence_of :information }
    it { is_expected.to validate_presence_of :access_token }
  end

  let(:facebook_file) { File.read(Rails.root.join('spec', 'fixtures', 'integration_data_facebook.json')) }
  let(:strava_file) { File.read(Rails.root.join('spec', 'fixtures', 'integration_data_strava.json')) }

  describe 'associate_with_user' do
    context 'facebook integration' do
      let(:info) { JSON.parse(facebook_file) }
      it 'associates with a user if the emails match' do
        user = FactoryBot.create(:user, email: 'foo.user@gmail.com')
        integration = FactoryBot.create(:integration, information: info)
        expect(user.id).to eq(integration.user.id)
      end

      it 'marks the user confirmed but not mark the terms of service agreed' do
        user = FactoryBot.create(:user, email: 'foo.user@gmail.com', confirmed: false, terms_of_service: false)
        integration = FactoryBot.create(:integration, information: info)
        expect(integration.user).to eq(user)
        expect(integration.user.confirmed).to be_truthy
        expect(integration.user.terms_of_service).to be_falsey
      end

      it 'creates a user, associate it if the emails match and run new user tasks' do
        expect do
          expect_any_instance_of(CreateUserJobs).to receive(:perform_create_jobs).and_return(true)
          FactoryBot.create(:integration, information: info)
        end.to change(User, :count).by 1
      end

      it 'deletes previous integrations with the same service' do
        integration = FactoryBot.create(:integration, information: info)
        expect(integration.user.confirmed).to be_truthy
        expect do
          FactoryBot.create(:integration, information: info)
        end.to change(Integration, :count).by 0
      end
    end

    context 'strava integration' do
      let(:info) { JSON.parse(strava_file) }
      it 'associates with a user if the emails match' do
        user = FactoryBot.create(:user, email: 'bar@example.com')
        integration = FactoryBot.create(:integration, information: info)
        expect(user.id).to eq(integration.user.id)
      end

      it 'marks the user confirmed but not mark the terms of service agreed' do
        user = FactoryBot.create(:user, email: 'bar@example.com', confirmed: false, terms_of_service: false)
        integration = FactoryBot.create(:integration, information: info)
        expect(integration.user).to eq(user)
        expect(integration.user.confirmed).to be_truthy
        expect(integration.user.terms_of_service).to be_falsey
      end

      it 'creates a user, associate it if the emails match and run new user tasks' do
        expect do
          expect_any_instance_of(CreateUserJobs).to receive(:perform_create_jobs).and_return(true)
          FactoryBot.create(:integration, information: info)
        end.to change(User, :count).by 1
      end

      it 'deletes previous integrations with the same service' do
        integration = FactoryBot.create(:integration, information: info)
        expect(integration.user.confirmed).to be_truthy
        expect do
          FactoryBot.create(:integration, information: info)
        end.to change(Integration, :count).by 0
      end
    end
  end
end
