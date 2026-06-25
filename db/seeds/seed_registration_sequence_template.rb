# Seeds the global RegistrationSequence template (org drafts are cloned from it).
# The template's pages live in the database; these are the defaults a fresh install
# starts with, including the bundled images when they're present on disk.
default_pages = [
  {
    image_path: "app/assets/images/registration_sequence/register.png",
    bullet_points: ["It only takes a minute", "Add your serial number and a photo", "Your registration is free, forever"]
  },
  {
    image_path: "app/assets/images/registration_sequence/protect.png",
    bullet_points: ["Mark it stolen in one click", "We alert the community and local shops", "Recovered bikes get reunited with their owners"]
  }
]

template = RegistrationSequence.template

default_pages.each_with_index do |attributes, index|
  page = template.registration_sequence_pages.find_or_create_by!(listing_order: index) do |new_page|
    new_page.bullet_points = attributes[:bullet_points]
  end

  next if page.image.attached?

  image_path = Rails.root.join(attributes[:image_path])
  next unless File.exist?(image_path)

  page.image.attach(io: File.open(image_path), filename: File.basename(image_path))
end
