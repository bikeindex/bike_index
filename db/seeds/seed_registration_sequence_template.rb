# Seeds the global RegistrationSequence template (org drafts are cloned from it).
# The template's pages live in the database; these are the defaults a fresh install
# starts with, including the bundled images when they're present on disk. `content` is
# Action Text (rich text), so the defaults are HTML.
default_pages = [
  {
    image_path: "app/assets/images/registration_sequence/register.png",
    content: "<ul><li>It only takes a minute</li><li>Add your serial number and a photo</li><li>Your registration is free, forever</li></ul>"
  },
  {
    image_path: "app/assets/images/registration_sequence/protect.png",
    content: "<ul><li>Mark it stolen in one click</li><li>We alert the community and local shops</li><li>Recovered bikes get reunited with their owners</li></ul>"
  }
]

template = RegistrationSequence.template

default_pages.each_with_index do |attributes, index|
  page = template.registration_sequence_pages.find_or_create_by!(listing_order: index) do |new_page|
    new_page.content = attributes[:content]
  end

  next if page.image.attached?

  image_path = Rails.root.join(attributes[:image_path])
  next unless File.exist?(image_path)

  page.image.attach(io: File.open(image_path), filename: File.basename(image_path))
end
