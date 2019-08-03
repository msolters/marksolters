source 'https://rubygems.org'

require 'json'
require 'open-uri'
versions = JSON.parse(open('https://pages.github.com/versions.json').read)

gem 'rough'
gem 'jekyll-paginate'
gem 'jekyll-geo-pattern'
gem 'kramdown'
gem 'jekyll-github-metadata'
gem 'github-pages', versions['github-pages']
