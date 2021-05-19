FROM ruby

COPY . /site
WORKDIR /site
ENV BUNDLE_GEMFILE='./Gemfile'
ENV BUNDLE_BIN=
RUN gem install bundler -v '~>1.17.3'
# RUN bundle install
RUN bundle _1.17.3_ update

CMD bundle _1.17.3_ exec jekyll serve
