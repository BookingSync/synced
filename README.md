# Synced

Synced is a Rails Engine that helps you keep local models synchronized with
their BookingSync representation.

Note: This synchronization is in one way only, from BookingSync to your
application. If you want to do a 2 way synchronization, you will need to
implement it yourself using
[BookingSync-API](https://github.com/BookingSync/bookingsync-api)

## Requirements

This engine requires BookingSync API `>= 0.0.17`, Rails `>= 4.0.0` and
Ruby `>= 2.0.0`.

## Documentation

[API documentation is available at rdoc.info](http://rdoc.info/github/BookingSync/synced/master/frames).

## Installation

Synced works with BookingSync API 0.0.17 onwards, Rails 4.0 onwards and Ruby
2.0 onwards. To get started, add it to your Gemfile with:

```ruby
gem 'synced'
```

Generate a migration to add Synced fields for the model you want to synchronize:

Example:
```console
rails g migration AddSyncedFieldsToRentals synced_id:integer:index \
  synced_data:text synced_updated_at:datetime
```

and migrate:

```console
rake db:migrate
```

And `synced` statement to the model you want to keep in sync.

Example:

```ruby
class Rental < ActiveRecord::Base
  synced
end
```

Run synchronization with given remote rentals

Example:

```ruby
Rental.synchronize(remote: remote_rentals)
```

Run rentals synchronization in website scope

Example:

```ruby
Rental.synchronize(remote: remote_rentals, scope: website)
```

## Custom fields for storing remote object data.

By default synced stores remote object in the following db columns.

    `synced_id` - ID of the remote object
    `synced_data` - Whole remote object is serialized into this attribute
    `synced_update_at` - Remote object's updated at

You can configure your own fields in `synced` declaration in your model.

```
class Rental < ActiveRecord::Base
  synced id_key: :remote_id, data_key: :remote_data, updated_at_key: :remote_updated_at
end
```

## Local attributes

All remote data is stored in `synced_data`, however sometimes it's useful to have some attributes directly in your model. You can use `local_attributes` for that.

```
class Rental < ActiveRecord::Base
  synced local_attributes: [:name, :size]
end
```

This assumes that model has name and size attributes. On every sychronization these two attributes will be assigned with value of `remote_object.name` and `remote_object.size` appropriately.

## Disabling synchronization for selected fields.

In some cases you only need one attribute to be synchronized and nothing more.
By default even when using local_attributes, whole remote object will be
saved in the `synced_data` and its updated_at in the `synced_updated_at`.
This may take additonal space in the database.
In order to disable synchronizing these fields, set their names in the `synced` declaration to nil, as in the below example:

```
class Rental < ActiveRecord::Base
  synced data_key: nil, updated_at_key: nil
end
```

You cannot disable synchronizing `synced_id` as it's required to match local
objects with the remote ones.

## Associations

It's possible to synchronize objects together with it's associations. For that
you need to

  1. Specify associations you want to synchronize within `synced`
    declaration of the parent model
  2. Add `synced` declaration to the associated model

```ruby
class Location < ActiveRecord::Base
  synced associations: :photos
  has_many :photos
end

class Photo < ActiveRecord::Base
  synced
  belongs_to :location
end
```

Then run synchronization of the parent objects. Every of the remote_locations
objects needs to respond to `remote_location[:photos]` from where data for
photos association will be taken.

```ruby
Location.synchronize(remote: remote_locations)
```

