FROM ruby:2.5.5
WORKDIR /src

RUN apt-get update -yq
RUN apt-get install imagemagick
RUN apt-get install curl gnupg -yq \
    && curl -sL https://deb.nodesource.com/setup_10.x | bash \
    && apt-get install nodejs -yq

RUN curl -o- -L https://yarnpkg.com/install.sh | bash \
    && ln -s $HOME/.yarn/bin/yarn /usr/local/bin/yarn

RUN apt-get install postgresql-client-11 -yq

COPY ./Gemfile /src/Gemfile
COPY ./Gemfile.lock /src/Gemfile.lock
RUN gem install bundler --conservative && bundle install

RUN yarn install
