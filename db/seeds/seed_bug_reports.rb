# Bug reports covering each bug-report-triage category, so the admin page and the triage skill
# have something to work on. Inline auto-prioritizing gives them the tags and statuses they'd
# get in production
bug_reports = [
  {email: "user@bikeindex.org", subject: "Photo upload broken",
   body: "Every time I try to add a photo to my bike the page spins and then says something went wrong. Tried two browsers."},
  {email: "rider@example.com", subject: "Form submission failed",
   body: "I filled out the stolen bike form and got \"Form submission failed\" when I pressed submit. Nothing saved."},
  {email: "member@brakebills.edu", subject: "Export registrations to CSV",
   body: "Could you add a way to download all my bikes as a spreadsheet for my insurance company?"},
  {email: "commuter@example.com", subject: "Re: Sign in to Bike Index",
   body: "I click the sign in link and it takes me back to the page asking for my email. I've tried four times."},
  {email: "user@fakegmail.com", subject: "Change primary email",
   body: "I don't use this address anymore, can you switch my account to my work email?"},
  {email: "privacy@example.com", subject: "Data erasure request",
   body: "Under the CCPA, please delete my account and all personal data you hold about me."},
  {email: "typo@example.com", subject: "Mistake on serial number",
   body: "I registered my bike yesterday and typed an 8 where the serial has a B. Please correct it."},
  {email: "seller@example.com", subject: "Sold bike",
   body: "I sold my cargo bike last weekend. How do I move the registration to the buyer?"},
  {email: "stolen@example.com", subject: "How to mark recovered",
   body: "My bike was stolen and I got it back the next day, but I can't find where to mark it recovered."},
  {email: "finder@example.com", subject: "Found bike",
   body: "A bike has been locked outside our building for a month. The serial matches a registration — how do I contact the owner?"},
  {email: "coordinator@example.edu", subject: "Registration sticker not received",
   body: "Our students registered through the campus program but the stickers never arrived."},
  {email: "officer@example.gov", subject: "Law enforcement partnership pricing",
   body: "Our department is researching bike registries. What does a partnership cost?"},
  {email: "developer@example.com", subject: "API access for a recovery app",
   body: "We're building a lost-and-found app and would like to search stolen bikes by serial through your API."},
  {email: "curious@example.com", subject: "Replacement key for e-bike",
   body: "I lost the key to my e-bike battery, can you send me a new one?"},
  {email: "growth@example.com", subject: "Guest posting opportunity",
   body: "We'd love to publish a sponsored article on bikeindex.org. What are your rates?"},
  {email: "notification@example.com", subject: "You're invited to test Meta AI Ads",
   body: "Action required: accept your invitation to join the Agency Partner Program before it expires."},
  {email: "away@example.com", subject: "Automatic reply: Please confirm your Bike Index email!",
   body: "I'm out of the office until Monday and will reply when I'm back."}
]

bug_reports.each do |attributes|
  SeedHelpers.tick
  bug_report = BugReport.create!(attributes.merge(receiver: "contact@bikeindex.org", received_at: Time.current))
  BugReportAutoPrioritizeJob.new.perform(bug_report.id)
end

puts "  Created #{bug_reports.count} bug reports"
