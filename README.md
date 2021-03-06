# UrlParamsManager

[![Gem Version](https://badge.fury.io/rb/url_params_manager.svg)](http://badge.fury.io/rb/url_params_manager)
[![Build Status](https://travis-ci.org/artirix/url_params_manager.svg?branch=master)](https://travis-ci.org/artirix/url_params_manager)
[![Code Climate](https://codeclimate.com/github/artirix/url_params_manager/badges/gpa.svg)](https://codeclimate.com/github/artirix/url_params_manager)
[![Test Coverage](https://codeclimate.com/github/artirix/url_params_manager/badges/coverage.svg)](https://codeclimate.com/github/artirix/url_params_manager/coverage)

Allows SEO Friendly urls for search pages to be built easily.
 
The urls will look like: `example.org/my-search/color-black/color-red/size-big/page-3` and will end up in this params: `{ color: ['black', 'red'], size: 'big', page: '3' }`.

## Usage

With this gem you can specify what parameters will be in the path and what will be added to the querystring. 

By default all parameters will be in the querystring, unless specified otherwise. Those are the *indexed params*.

The indexed params follow these rules:

1. they will be added in a `"#{param_prefix}-#{value}` pairs.
2. the order of the pairs in the URL is determined by the priority of the params in the config
3. in case of multivalued, multiple param-value pairs will be added, following value's alphabetical order

### Param name vs Param Prefix

We use this to "translate" the params from how they're known in the app to what they're known in the URLs. With this, we can change how the param is named in the URLs without changing it in the app. This will help us with white-labels config, multi-language configs, or SEO/UX related changes.

The "Param Name" or "Param name in the App" is how the param is known in the app, how it'll be accessed in Rails' params.
The "Param Prefix" or "Param alias in the URL" is how the param will be shown in the URL, either in the path or in the querystring.

The "prefix -> name" map are set on the config of the UrlParamsManager.

By default, if the config does not say otherwise, the prefix and the name are the same.

important: if the param is an indexed param (it's shown in the path not in the querystring), then we have to add it to this hash, even with the same name:
ie: 

```ruby
map = {
  prefix:    :real_name,
  same_name: :same_name,
  page:      :page,
}
```

### Indexed vs non Indexed params

Indexed params appear in the path, ordered (following a priority order set in the config of the UrlParamsManager).

Non Indexed params are every other param, and they appear in the querystring.

note: We specify the indexed params using the Param Prefix (aka Param alias in the URL)

note: Indexed Params may have multiple values but those will be *UNORDERED*. (See the example for reasoning).

### Default Values

The config can specify default values for specific params. That means that:

- if the param does not appear in the URL, we'll give the param the default value in the app.
- if the param is given the default app, the resulting URL will not have the param: if the param has the default value it is ignored when building the URL.

The default value can be a list.

note: We specify the default values using the Param Name. 

## Example of use and Config

### UrlParamsManager object

```ruby
# List of Params Prefixes to be considered as indexed params (in the path, not in the querystring)
indexed_url_params_order = [
  :feat,
  :cap,
  :ndef,
  # ALWAYS LAST
  :page
]

# Param Prefix => Param name in the app
url_to_filter_params = {
  feat: :feature, # indexed => in URL
  cap:  :capacity, # indexed => in URL
  some: :something, # not indexed => in querystring
  ndef: :non_default, # value with default
  # page: :page, # if it is the same and it is present in `indexed_url_params_order`, we don't need to pass it.
}

# Default values for the params
default_params = {
  something:          99,
  non_default:        'paco',
  with_default_value: 2,
  with_default_list:  [1, 2],
}

# UrlParamsManager object
@upm = UrlParamsManager.for url_to_filter_params:     url_to_filter_params, # Param Name Map
                            indexed_url_params_order: indexed_url_params_order, # Indexed Params list
                            app_url_helpers:          Rails.application.routes.url_helpers, # Object to receive the URL's Path calls (usually Rails URL Helpers)
                            default_params:           default_params # Default Params map
```

### `filter_params_treatment`

`UrlParamsManager` object can receive a `filter_params_treatment` option with a callable object.
The `filter_params` will be passed to that callable object before returning on `filters_from_url_params` calls
as well as at the beginning of `url_args_from_filters` calls.

### `filter_params_pretreatment`

same as `filter_params_treatment` but it's applied to the url_params at the beginning of `filters_from_url_params` calls only, right after symbolizing the keys.

### `always_lists_fields`

`UrlParamsManager` object can receive a `always_lists_fields` option with:

- a list of fields to be converted to Array (ie: `[:multi, :another_multi]`)
- a hash having the fields as keys and values either `true` (convert to Array) or a regex or string to use to `split`): (ie: `{ multi: true, another_multi: ',' }`)


### Building URLs
 
```ruby
pars = {
  capacity:           ['25+'],
  page:               2,
  feature:            ['swimming-pool', 'helipad'],
  something:          ['other', 'another'],
  with_default_value: 2,
  with_default_list:  [2, 1],
  non_default:        'ohmy',
}

expected_path = @upm.my_search_path(pars) 
  # => '/search/feat-helipad/feat-swimming-pool/cap-25+/ndef-ohmy/page-2?some%5B%5D=another&some%5B%5D=other'

# capacity => indexed with prefix 'cap'
# page => indexed with prefix 'page'
# feature => indexed with prefix 'feat'. Both values are shown, alpha-ordered.
# something => not indexed, using prefix (or 'Param Alias in URL') as key and the values alpha-ordered.
# with_default_value => since it has the default value, it does not appear
# with_default_list => since it has the default value, it does not appear. Note that we gave it the same values but in different order
# non_default => indexed with prefix 'ndef'

```

### Rails config for interpreting the URL

routes.rb file:
```ruby

Rails.application.routes.draw do
  
  get 'search(/*filters)', to: 'articles#index', as: :my_search
end
```

With that routes config, we'll have in `params` in the controller the indexed params plus a param "filters" with the string of all the indexed params.

We'll use the UrlParamsManager defined before to convert that into a hash of params that we can use internally.

This will put together the indexed params in the path with the non indexed params in the querystring, and it will translate the param names back to the Param name to use in the app.

```ruby
class ArticlesController < ApplicationController

  SEARCH_IGNORE_PARAMS = ['controller', 'action'].map &:freeze

  def index
    @articles = Article.search(search_params)
  end

  private
  def search_params
    @upm.filters_from_url_params params.reject { |k, _| SEARCH_IGNORE_PARAMS.include? k }
  end
end
```

With a URL like we built before: `'/search/feat-helipad/feat-swimming-pool/cap-25+/ndef-ohmy/page-2?some%5B%5D=another&some%5B%5D=other'` and this config, `Article.search` will receive a hash with:

```ruby
{
  capacity:           '25+',
  page:               2,
  feature:            ['helipad', 'swimming-pool'],
  something:          ['another', 'other'],
  with_default_value: 2,
  with_default_list:  [1, 2],
  non_default:        'ohmy',
}
```

## With Position-Defined params

Sometimes we want the first url parts to have a preassigned meaning. For example, we may want something like 
`/search/my-location/my-category/page-3`, where the first 2 params will be interpreted as `params[:locations]` and `params[:categories]`.

With the `position_defined_url_params` option we can pass a hash with the config for these kind of params. 

Important observations:

- the position-defined params hash is **ordered**. The position will be determined by the order of the keys of the config hash.
- all position defined param needs a **placeholder**. This will be:
  - ignored when translating from url to filter
  - added to the url in its place if a posterior param is present (or if `force_placeholder` option is passed as true), so we can respect the position order.
- when the param has multiple values, instead of adding them in separate parts, we'll concatenate them using a separator:
  - it can be passed as `multiple_separator` option
  - if not passed, it will use a default separator `--`.
- when recognising params from the url, we'll **stop looking for position defined params when we first recognise a prefix of a normal param**

The last part is important because it allows us to combine normal indexed params with position based params. 

Example:

```ruby
url_to_filter_params = {}
indexed_url_params_order = [:by_prefix, :page]
position_defined_url_params = {
  locations:  { placeholder: 'all-locations', multiple_separator: '--' },
  categories: { placeholder: 'all-categories', multiple_separator: '_AND_' },
  themes:     { placeholder: 'all-themes', multiple_separator: '--' },
  offers:     { placeholder: 'all-offers' } # uses default separator
}

@upm = UrlParamsManager.for url_to_filter_params:       url_to_filter_params, # Param Name Map
                            indexed_url_params_order:   indexed_url_params_order, # Indexed Params list
                            position_defined_url_params: position_defined_url_params, # Position Defined params config
                            app_url_helpers:            Rails.application.routes.url_helpers, # Object to receive the URL's Path calls (usually Rails URL Helpers)

# FILTERS -> URL
pars = {
  categories:       ['my-cat', 'second-cat'],
  offers:           'my-offer',
  by_prefix_filter: ['hey', 'you'],
  some:             ['other', 'another'],
  page:             '2'
}

# it adds the needed placeholders
expected_path = @upm.my_search_path(pars) 
  # => '/search/all-locations/my-cat_AND_second-cat/all-themes/my-offer/by_prefix-hey/by_prefix-you/page-2?some%5B%5D=another&some%5B%5D=other'


# example with less position based because we encounter one normal arg (page)
url_params = {
  filters: 'all-locations/my-cat_AND_second-cat/one-theme--second-theme/page-2'
}
expected_params = filters_from_url_params(url_params)
 # => { 
        categories:   ['my-cat', 'second-cat'],
        themes:       ['one-theme', 'second-theme'],
        page:         '2'
      }

# `all-locations`, being `locations` placeholder, is ignored
# `page-2` is recognised as `page`, not as `offers`.
```


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'url_params_manager'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install url_params_manager

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/artirix/url_params_manager/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Changeset

### v.0.6.0

- added `force_placeholder` option to `position_defined_url_params`.

### v.0.5.0

- added `filter_params_pretreatment` option.

### v.0.4.0
- fixed typo in `position_defined_url_params` (it was position_defined_url_parms)
- added `always_lists_fields` option.

### v.0.2.0

- added `filter_params_treatment` option.

## Yanked Versions

### v.0.3.0: YANKED!

- added `position_defined_url_params` option.
