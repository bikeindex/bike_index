require "rails_helper"

RSpec.describe CarrierWaveVersionWarmer do
  describe ".warm!" do
    it "builds every version subclass with its version_options assigned" do
      described_class.warm!

      version_classes = ObjectSpace
        .each_object(CarrierWave::Uploader::Base.singleton_class)
        .select { |klass| klass.version_names.any? }

      expect(version_classes).to include(AvatarUploader.const_get(:VersionUploaderMedium))
      version_classes.each do |klass|
        # The race the warmer prevents leaves version_options nil, which blows up
        # in CarrierWave's version_active?.
        expect(klass.version_options).not_to be_nil
      end
    end
  end
end
