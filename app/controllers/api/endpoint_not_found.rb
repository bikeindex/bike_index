module API
  # Raised by each root's catch-all route. A type, so the 404 doesn't depend on the message -
  # matching /unable to find/ turned real bugs worded that way into unreported 404s.
  class EndpointNotFound < StandardError
  end
end
