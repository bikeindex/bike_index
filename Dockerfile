FROM ruby:4.0.2

RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
  && apt-get install -y --no-install-recommends \
    nodejs \
    libpq-dev \
    imagemagick \
    libvips-dev \
    postgresql-client \
    git \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY package.json package-lock.json ./
RUN npm ci

CMD ["bin/dev"]
