module API
  # Raised by each root's catch-all route. A type rather than a message, so the 404 doesn't
  # depend on prose - matching /unable to find/ also caught real bugs worded that way, and
  # silently dropped them from Honeybadger along with the status.
  class EndpointNotFound < StandardError
  end
end
