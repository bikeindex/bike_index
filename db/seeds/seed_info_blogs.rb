# Seed the blogs that top-level info pages render by slug. InfoController#why_donate
# and #membership do `Blog.friendly_find(<slug>)` then render news/show, which
# fails loudly (NoMethodError on @blog.user) when the blog is missing — so these
# must exist for /why-donate and /membership to work (e.g. on review apps).
author = User.find_by(email: "admin@bikeindex.org") || User.first

[
  ["End 2020 with a donation to Bike Index", Blog.why_donate_slug],
  ["Bike Index Membership", Blog.membership_slug]
].each do |title, slug|
  next if Blog.friendly_find(slug).present?

  Blog.create!(
    title:,
    body: "Seeded \"#{title}\" content for review apps.",
    user: author,
    info_kind: true, # kind: info — top-level info page, not a news post
    published: true
  )
end
