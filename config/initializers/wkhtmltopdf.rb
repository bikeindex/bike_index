if Rails.env.production?
  WickedPdf.config = {
    :exe_path => '/usr/bin/wkhtmltopdf'
  }
end
