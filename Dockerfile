FROM ruby:2.5.5
WORKDIR /src

RUN apt-get update -yq \

    # imagemagick
    && apt-get install imagemagick \
    && apt-get install curl gnupg -yq \

    # node js
    && curl -sL https://deb.nodesource.com/setup_10.x | bash \
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

RUN yarn install
