# Eager-build every CarrierWave version subclass at boot.
#
# CarrierWave builds a version's uploader subclass lazily on first access
# (CarrierWave::Uploader::Versions::Builder#build), and that build isn't
# thread-safe: under Puma a second thread can grab the half-built class before
# `version_options` is assigned, raising "undefined method '[]' for nil" in
# `version_active?`. Building them once, single-threaded, removes the race.
module CarrierWaveVersionWarmer
  # Subclasses of CarrierWave::Uploader::Base are instances of its singleton
  # class, so this enumerates the base uploader and everything derived from it.
  def self.warm!
    ObjectSpace.each_object(CarrierWave::Uploader::Base.singleton_class) { |klass| build(klass) }
  end

  def self.build(uploader_class)
    uploader_class.versions.each_value { |builder| build(builder.build(uploader_class)) }
  end
end
