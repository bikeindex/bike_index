FROM ruby:2.7.3
WORKDIR /src

RUN apt-get update -yq \
    && apt-get install curl gnupg -yq \

    # imagemagick
    && apt-get install imagemagick \

    # node js
    && curl -sL https://deb.nodesource.com/setup_12.x | bash \
    && apt-get install nodejs -yq \

    # yarn
    && curl -o- -L https://yarnpkg.com/install.sh | bash \
    && ln -s $HOME/.yarn/bin/yarn /usr/local/bin/yarn \

    # PostgreSQL Client
    && apt-get install postgresql-client-11 -yq

COPY ./Gemfile /src/Gemfile
COPY ./Gemfile.lock /src/Gemfile.lock
COPY ./package.json /src/package.json
COPY ./yarn.lock /src/yarn.lock

RUN gem install bundler --conservative && bundle install

RUN yarn install --check-files
