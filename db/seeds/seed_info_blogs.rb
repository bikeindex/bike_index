# Seed the blogs that top-level info pages render by slug. InfoController#why_donate
# and #membership do `Blog.friendly_find(<slug>)` then render news/show, which
# fails loudly (NoMethodError on @blog.user) when the blog is missing — so these
# must exist for /why-donate and /membership to work (e.g. on review apps).
author = User.find_by(email: "admin@bikeindex.org") || User.first

why_donate_body = <<~HTML
  # <strong>10+ Years of Bike Index and Counting!!!</strong>
  Thank you to everyone who has been part of Bike Index's journey! Each year we grow more than ever, registering and recovering bikes at rates we dreamed of when all of this started over a decade ago. <strong>We rely on your continued support</strong>.

  <a class="btn btn-primary" href="/donate?source=why-donate">Donate today</a>

  2024 has been a big year for us, we officially passed over <strong>1 Million bikes registered on Bike Index</strong>. We added over 100 new partner organizations ranging from advocacy groups to bike shops to University and law enforcement. We're continually refining and improving our offerings to help more people register and recover their bikes for free. This is an exciting period for us and we need you more than ever to continue this work and keep it free for everyone.

  <img width="100%" class='post-image' src='https://files.bikeindex.org/uploads/Pu/365516/hi.png' alt='recovery 2'>
HTML

[
  {title: "Donate to Bike Index", slug: Blog.why_donate_slug, body: why_donate_body,
   secondary_title: "Thank you to everyone who has been part of Bike Index's journey! 10+ years and counting!"},
  {title: "Bike Index Membership", slug: Blog.membership_slug}
].each do |attrs|
  next if Blog.friendly_find(attrs[:slug]).present?

  blog = Blog.create!(
    title: attrs[:title],
    secondary_title: attrs[:secondary_title],
    body: attrs[:body] || "Seeded \"#{attrs[:title]}\" content for review apps.",
    user: author,
    info_kind: true, # kind: info — top-level info page, not a news post
    published: true
  )
  # Pin the slug the info page looks up, since it's derived from the title
  blog.update(title_slug: attrs[:slug]) if blog.title_slug != attrs[:slug]
end
