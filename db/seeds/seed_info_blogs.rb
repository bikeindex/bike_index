# Seed the blogs that top-level info pages render by slug — without the row, /why-donate
# and /membership raise, and the navbar's and footer's stolen-bike link quietly redirects
# to /news. Bodies are the copy bikeindex.org serves, so review apps show the real page.
author = User.find_by(email: "admin@bikeindex.org") || User.first

[
  {title: "Donate to Bike Index", slug: Blog.why_donate_slug,
   secondary_title: "Thank you to everyone who has been part of Bike Index's journey! 10+ years and counting!"},
  {title: "Bike Index Membership", slug: Blog.membership_slug},
  {title: "E-Vehicle Acknowledgment FAQ", slug: Blog.e_vehicle_acknowledgment_faq},
  {title: "How to get your stolen bike back", slug: Blog.get_your_stolen_bike_back_slug}
].each do |attrs|
  next if Blog.friendly_find(attrs[:slug]).present?

  body_path = Rails.root.join("db/seeds/info_blogs/#{attrs[:slug]}.md")

  blog = Blog.create!(
    title: attrs[:title],
    secondary_title: attrs[:secondary_title],
    body: body_path.exist? ? body_path.read : "Seeded \"#{attrs[:title]}\" content for review apps.",
    user: author,
    info_kind: true, # kind: info — top-level info page, not a news post
    published: true
  )
  # Pin the slug the info page looks up, since it's derived from the title
  blog.update(title_slug: attrs[:slug]) if blog.title_slug != attrs[:slug]
end
