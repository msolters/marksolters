FROM ruby

COPY . /site
WORKDIR /site
RUN gem install bundler
# RUN bundle install
RUN bundle update

CMD bundle exec jekyll serve
