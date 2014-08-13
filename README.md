[![Code Climate](https://codeclimate.com/github/BookingSync/synced.png)](https://codeclimate.com/github/BookingSync/synced)
[![Build Status](https://travis-ci.org/BookingSync/synced.png?branch=master)](https://travis-ci.org/BookingSync/synced)

# Synced

Synced is a Rails Engine that helps you keep local models synchronized with
their BookingSync representation.

It decreases time needed to fetch data from BookingSync API. If given endpoint
supports `updated_since` parameter, Synced will first perform a full
synchronization and then every next synchronization will only synchronize
added/changed/deleted objects since last synchronization.

## Requirements

This engine requires Rails `>= 4.0.0` and Ruby `>= 2.0.0`.

## Installation

To get started, add it to your Gemfile with:

```ruby
gem 'synced'
```
and run `bundle install`

## Basic usage

Assume we want to create an application displaying rentals from multiple
BookingSync accounts and we want to synchronize rentals to make it snappy
and traffic efficient.

We will surely have `Rental` and `Account` models. Where `Account` will have
`BookingSync::Engine::Account` mixin and thus respond to `api` method.

First generate a migration to add synced fields to the model.
These fields will be used for storing data from the API.

Example:

```console
rails g migration AddSyncedFieldsToRentals synced_id:integer:index \
  synced_data:text synced_all_at:datetime
```

and migrate:

```console
rake db:migrate
```

Add `synced` statement to the model you want to keep in sync and add `api`
method which return instance of `BookingSync::API::Client` used for fetching
data.

```ruby
class Rental < ActiveRecord::Base
  synced
  belongs_to :account
end
```

Example:

Synchronize rentals for given account.

```ruby
Rental.synchronize(scope: account)
```

Now rentals details fetched from the API are accessible through `synced_data`
method.

```ruby
rental = account.rentals.first
rental.synced_data.bedrooms # => 4
rental.synced_data.rental_type # => "villa"
```

## Synced database fields

Option name          | Default value    | Description                             | Required |
---------------------|------------------|-----------------------------------------|----------|
`:id_key`            | `:synced_id`     | ID of the object fetched from the API   | YES      |
`:data_key`          | `:synced_data`   | Stores data fetched from the API        | NO       |
`:synced_all_at_key` | `:synced_all_at` | Stores time of the last synchronization | NO       |

Custom fields name can be configured in the `synced` statement of your model:

```ruby
class Rental < ActiveRecord::Base
  synced id_key: :remote_id, data_key: :remote_data,
    synced_all_at_key: :remote_all_synced_at
end
```

## Local attributes

Whole remote data is stored in `synced_data` column, however sometimes it's
useful (for example for sorting) to have some attributes directly in your model.
You can use `local_attributes` to achieve it:

```ruby
class Rental < ActiveRecord::Base
  synced local_attributes: [:name, :size]
end
```

This assumes that model has `name` and `size` attributes.
On every synchronization these two attributes will be assigned with value of
 `remote_object.name` and `remote_object.size` appropriately.

### Local attributes with custom names

If you want to store attributes from remote object under different name, you
need to pass your own mapping hash to `synced` statement.
Keys are local attributes and values are remote ones. See below example:

```ruby
class Rental < ActiveRecord::Base
  synced local_attributes: { headline: :name, remote_size: :size }
end
```

During synchronization to local attribute `headline` will be assigned value of
`name` attribute of the remote object and to the local `remote_size` attribute
will be assigned value of `size` attribute of the remote object.

### Local attributes with mapping blocks

If you want to convert an attributes value during synchronization you can
pass a block as value in the mapping hash. Block will receive remote object
as the only argument.

```ruby
class Rental < ActiveRecord::Base
  synced local_attributes: { headline: ->(rental) { rental.headline.downcase } }
end
```

### Local attributes with mapping modules

Converting remote object's values with blocks is really easy, but when you get
more attributes and longer code in the blocks they might become quite complex
and hard to read. In such cases you can use a mapper module.
Remote object will be extended with it.

```ruby
class Rental < ActiveRecord::Base
  module Mapper
    def downcased_headline
      headline.downcase
    end
  end
  synced mapper: Mapper, local_attributes: { headline: :downcased_headline }
end
```

If you want to define Mapper module after the synced directive, you need to
pass Mapper module inside a block to avoid "uninitialized constant" exception.

```ruby
class Rental < ActiveRecord::Base
  synced mapper: -> { Mapper },
    local_attributes: { headline: :downcased_headline }
  module Mapper
  end
end
```

## Partial updates (using updated since parameter)

Partial updates mean that first synchronization will copy all of the remote
objects into local database and next synchronizations will sync only
added/changed and removed objects. This significantly improves synchronization
time and saves network traffic.

In order to enable it add timestamp column named `synced_all_at` to your
database. Synced will automatically detect it.

NOTE: In order it to work, given endpoint needs to support updated_since
parameter. Check [API documentation](http://docs.api.bookingsync.com/reference/)
for given endpoint.

## Disabling saving whole synced_data

If you don't need whole remote object to be stored in local object skip
creating `synced_data` column in the database or set `synced_data_key: nil`.

If you don't want to synchronize only added/changed or deleted objects but all
objects every time, don't create `synced_all_at` column in the database or set
`synced_all_at: false` in the synced statement.

You cannot disable synchronizing `synced_id` as it's required to match local
objects with the remote ones.

## Associations

It's possible to synchronize objects together with it's associations. Meaning
local associated objects will be created. For that you need to:

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
Location.synchronize
```

NOTE: It assumes that local association `photos` exists in `Location` model.

## Including associations in synced_data

When you need associated data available in the local object, but you don't
need it to be a local association, you can use `include:` option in model or
synchronize method.

```ruby
class Location < ActiveRecord::Base
  synced include: :photos
end

Location.first.synced_data.photos # => [{id: 1}, {id: 2}]
```

You can also specify `include:` option in synchronize method. In this case it
will overwrite `include:` from the model.

```ruby
Location.synchronize(include: :addresses)
```

## Synchronization of given remote objects

By default synced will fetch remote objects using BookingSync::API::Client
but in some cases you might want to provide own list of remote objects to
synchronize. In order to do that provide them as `remote:` option to synchronize
method.

```ruby
Location.synchronize(remote: remote_locations)
```

NOTE: Partial updates are disabled when providing remote objects.

## Removing local objects

By default synchronization will not delete any local objects which are removed
on the API side. In order to remove local objects removed on the API, specify
`remove: true` in the model or as an option to synchronize method.

```ruby
class Photo < ActiveRecord::Base
  synced remove: true
end
```

Option `remove:` passed to `Photo.synchronize` method will overwrite
configuration in the model.

For objects which need to be removed `:destroy_all` is called.
If model has `canceled_at` column, local objects will be canceled with
`:cancel_all` class method. You can force your own class method to be called on
the local objects which should be removed by passing it as an symbol.

```ruby
class Photo < ActiveRecord::Base
  synced remove: :mark_as_outdated

  def self.mark_as_outdated
    all.update_attributes(outdated: true)
  end
end
```

## Selecting fields to be synchronized

Very often you don't need whole object to be fetched and stored in local
database but only several fields. You can specify which fields should be fetched
and stored with `fields:` option.

```ruby
class Photo < ActiveRecord::Base
  synced fields: [:name, :url]
end
```

This can be overwritten in synchronize method.

```ruby
Photo.synchronize(fields: [:name, :size])
```

## Synced configuration options

Option name          | Default value    | Description                                                                       | synced | synchronize |
---------------------|------------------|-----------------------------------------------------------------------------------|--------|-------------|
`:id_key`            | `:synced_id`     | ID of the object fetched from the API                                             | YES    | NO          |
`:data_key`          | `:synced_data`   | Object fetched from the API                                                       | YES    | NO          |
`:synced_all_at_key` | `:synced_all_at` | Time of the last synchronization                                                  | YES    | NO          |
`:associations`      | `[]`             | [Sync remote associations to local ones](#associations)                           | YES    | NO          |
`:local_attributes`  | `[]`             | [Sync remote attributes to local ones](#local-attributes)                         | YES    | NO          |
`:mapper`            | `nil`            | [Module used for mapping remote objects](#local-attributes-with-mapping-modules)  | YES    | NO          |
`:remove`            | `false`          | [If local objects should be removed when deleted on API](#removing-local-objects) | YES    | YES         |
`:include`           | `[]`             | [An array of associations to be fetched](#including-associations-in-synced_data)  | YES    | YES         |
`:fields`            | `[]`             | [An array of fields to be fetched](#selecting-fields-to-be-synchronized)          | YES    | YES         |
`:remote`            | `nil`            | [Remote objects to be synchronized with local ones](#synchronization-of-given-remote-objects) | NO | YES |

## Documentation

[API documentation is available at rdoc.info](http://rdoc.info/github/BookingSync/synced/master/frames).
