# Ensures the default RegistrationSequence template exists (org drafts are seeded from it).
# Page bodies come from RegistrationSequence::DEFAULT_PAGES via RegistrationSequence.template;
# here we attach the bundled default images when they're present on disk.
template = RegistrationSequence.template

RegistrationSequence::DEFAULT_PAGES.each_with_index do |attributes, index|
  page = template.pages.find_by(listing_order: index)
  next if page.nil? || page.image.attached?

  image_path = Rails.root.join(attributes[:image_path])
  next unless File.exist?(image_path)

  page.image.attach(io: File.open(image_path), filename: File.basename(image_path))
end
