# Synced

Synced is a Rails Engine that helps you keep local models synchronized with their BookingSync representation.

Note: This synchronization is in one way only, from BookingSync to your application. If you want to do a 2 way synchronization, you will need to implement it yourself using [BookingSync-API](https://github.com/BookingSync/bookingsync-api)

## Requirements

This engine requires BookingSync API `>= 0.0.17`, Rails `>= 4.0.0` and Ruby `>= 2.0.0`.

## Documentation

[API documentation is available at rdoc.info](http://rdoc.info/github/BookingSync/synced/master/frames).

## Installation

Synced works with BookingSync API 0.0.17 onwards, Rails 4.0 onwards and Ruby 2.0 onwards. To get started, add it to your Gemfile with:

```ruby
gem 'synced'
```

Then run the installer to copy the migrations,

```console
rake synced:install:migrations
```

Then, generate a migration to add Synced fields for the model you want to synchronize:

Example:
```console
rails g migration AddSyncedFieldsToRentals synced_id:integer:index synced_data:text \
  synced_updated_at:datetime
```

and migrate:

```console
rake db:migrate
```

And include `Synced::HasSyncedData` in the model you want to keep in sync:

```ruby
class Account < ActiveRecord::Base
  include Synced::HasSyncedData
end
```
