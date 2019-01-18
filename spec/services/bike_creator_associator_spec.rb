require 'spec_helper'

describe BikeCreatorAssociator do
  let(:subject) { BikeCreatorAssociator }
  let(:instance) { subject.new }
  describe 'create_ownership' do
    it 'calls create ownership' do
      b_param = BParam.new
      bike = Bike.new
      allow(b_param).to receive(:params).and_return({ bike: bike }.as_json)
      allow(b_param).to receive(:creator).and_return('creator')
      expect_any_instance_of(OwnershipCreator).to receive(:create_ownership).and_return(true)
      subject.new(b_param).create_ownership(bike)
    end
    it 'calls create ownership with send_email false if b_param has that' do
      b_param = BParam.new
      bike = Bike.new
      allow(b_param).to receive(:params).and_return({ bike: { send_email: false } }.as_json)
      allow(b_param).to receive(:creator).and_return('creator')
      expect_any_instance_of(OwnershipCreator).to receive(:create_ownership).and_return(true)
      subject.new(b_param).create_ownership(bike)
    end
  end

  describe 'create_components' do
    it 'calls create components' do
      b_param = BParam.new
      bike = Bike.new
      expect_any_instance_of(ComponentCreator).to receive(:create_components_from_params).and_return(true)
      subject.new(b_param).create_components(bike)
    end
  end

  describe 'create_normalized_serial_segments' do
    it 'calls create components' do
      b_param = BParam.new
      bike = Bike.new
      expect_any_instance_of(SerialNormalizer).to receive(:save_segments).and_return(true)
      subject.new(b_param).create_normalized_serial_segments(bike)
    end
  end

  describe 'create_stolen_record' do
    it 'calls create stolen record' do
      b_param = BParam.new
      bike = Bike.new
      allow(bike).to receive(:creation_organization).and_return(true)
      expect_any_instance_of(StolenRecordUpdator).to receive(:create_new_record).and_return(true)
      subject.new(b_param).create_stolen_record(bike)
    end
  end

  describe 'add_other_listings' do
    it 'calls create stolen record' do
      b_param = BParam.new
      bike = FactoryBot.create(:bike)
      urls = ['http://some_blog.com', 'http://some_thing.com']
      allow(b_param).to receive(:params).and_return({ bike: { other_listing_urls: urls } }.as_json)
      subject.new(b_param).add_other_listings(bike)
      expect(bike.other_listings.reload.pluck(:url)).to eq(urls)
    end
  end

  describe 'attach_photo' do
    it 'creates public images for the attached image' do
      bike = FactoryBot.create(:bike)
      b_param = FactoryBot.create(:b_param)
      test_photo = Rack::Test::UploadedFile.new(File.open(File.join(Rails.root, 'spec', 'fixtures', 'bike.jpg')))
      b_param.image = test_photo
      b_param.save
      expect(b_param.image).to be_present
      b_param.params = p
      subject.new(b_param).attach_photo(bike)
      expect(bike.public_images.count).to eq(1)
    end
  end

  # describe 'add_uploaded_image' do
  #   it "associates the public image" do
  #     bike = FactoryBot.create(:bike)
  #     b_param = FactoryBot.create(:b_param)
  #     b_param.params = {bike: {bike_image: File.open(File.join(Rails.root, 'spec', 'fixtures', 'bike.jpg'))}}
  #     b_param.save
  #     subject.new(b_param).add_uploaded_image(bike)
  #     bike.reload.public_images.count.should eq(1)
  #   end
  # end

  describe "updated_phone" do
    let(:user) { FactoryBot.create(:user) }
    let(:bike) { Bike.new(phone: "699.999.9999") }
    before { allow(bike).to receive(:user) { user } }
    it "sets the owner's phone if one is passed in" do
      instance.assign_user_attributes(bike)
      user.reload
      expect(user.phone).to eq("6999999999")
    end
    context "user already has a phone" do
      let(:user) { FactoryBot.create(:user, phone: "0000000000") }
      it 'does not set the phone if the user already has a phone' do
        instance.assign_user_attributes(bike)
        user.reload
        expect(user.phone).to eq("0000000000")
      end
    end
  end

  describe 'associate' do
    it 'calls the required methods' do
      bike = Bike.new
      creator = subject.new
      allow(bike).to receive(:stolen).and_return(true)
      expect(creator).to receive(:create_ownership).and_return(bike)
      expect(creator).to receive(:create_stolen_record).and_return(bike)
      expect(creator).to receive(:create_components).and_return(bike)
      expect(creator).to receive(:create_normalized_serial_segments).and_return(bike)
      expect(creator).to receive(:assign_user_attributes)
      expect(creator).to receive(:attach_photo)
      expect(creator).to receive(:attach_photos)
      expect(creator).to receive(:add_other_listings)
      creator.associate(bike)
    end
    it 'rescues from the error and add the message to the bike' do
      expect(StolenRecordUpdator).to be_present # Load the error
      bike = Bike.new
      creator = subject.new
      allow(bike).to receive(:stolen).and_return(true)
      allow(bike).to receive(:create_stolen_record).and_raise(StolenRecordError, 'Gobledy gook')
      creator.associate(bike)
      expect(bike.errors.messages[:association_error]).not_to be_nil
    end
  end
end
