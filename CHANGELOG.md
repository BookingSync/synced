## master

## 2.0.0 - 2022-12-16

* Drop support for ruby prior to 2.7
* Add support for ruby 3.0 and 3.1
* Drop support for rails prior to 6
* Update and lock bookingsync-api at `>= 1`

## 1.8.0 - 2018-04-30

* [feature] Model aliasing. added `endpoint` option to synced to determine the model to sync. For example, in user.rb `endpoint: :persons` will look for `Person` class instead of `User`

## 1.7.0 - 2018-02-27

* [feature] Synced will accept tolerance param which reduces updated_since value by specified amount of seconds.

## 1.6.1 - 2017-10-12

* [improvement] Move default value of `data_key` fetch to block.

## 1.6.0 - 2017-06-22

* [feature] Allow to have a transaction per page of fetched objects by using :transaction_per_page option
* [enhancement] Support only Ruby 2.3+

## 1.5.2
  * [bugfix] Fix n + 1 query problems
  * [feature] Allow to choose method of fetching data (with auto_paginate or in batches). Fetching in batches should reduce memory usage. Defaults to auto_paginate, hence no changes required after update.
  * [improvement] Update bookingsync-api gem to 0.1.4

## 1.4.0
  * [bugfix] For paginated updated_since syncs use the timestamp from the first page. This should prevent any data loss during updated_since synchronization, fixing inconsistencies in the next sync.

## 1.3.0
  * [feature] Make scope no longer required for SyncedPerScopeTimestampStrategy (if you already have created the table, you should remove `null: false` constraint for `parent_scope_id` and `parent_scope_type` columns)

## 1.2.0
  * [refactor] Delegate `reset_synced` functionality to strategy
  * [refactor] Extract updated_since timestamps (`synced_all_at`) as a separate strategy, add second timestamps strategy that uses external table instead of `synced_all_at` fields.
  * [refactor] Removed dynamic strategy resolution. :updated_since is now a default strategy, to use :full strategy specify it in synced declaration, `synced strategy: :full`
  * [refactor] Change `search_params` to `query_params`

## 1.1.3
  * [bugfix] Do not perform requests for blank has_one associations

## 1.1.2
  * [bugfix] Fix remote_objects array wrapping to allow single remote_object sync to local association

## 1.1.1
  * [feature] Allow to filter records with `search_params` when syncing
  * [bugfix] Memoize api instance at strategy level to properly return last_response for meta
  * [refactor] Remove dummy api class method memoization, as it is an unrealistic scenario
  * [improvement] Add `pry` development_dependency

## 1.1.0
  * [feature] Add check strategy, which doesn't do any synchronization it simply compares objects from the API with the one in local database and returns a diff.
  * [refactor] Synchronization code has been split into 3 strategies.

## 1.0.9
  * [improvement] Better exception message on missing API client
  * [improvement] Update bookingsync-api gem to 0.0.24

## 1.0.8
  * [feature] Add delegate_attributes for easier access to data stored in `synced_data` column

## 1.0.7
  * [bugfix] Fix bug when only_updated: true and remove: true used. It was causing all records to be removed and then synchronized again
    on the next synchronization.

## 1.0.6
  * [bugfix] Fix selecting data for updated_since when there are object in the
    relation

## 1.0.5
  * [feature] When using partial updates (updated_since param) it's now possible
  to synchronize objects from given point in time by passing initial_sync_since
  option as value or block.

## 1.0.4
  * [bugfix] Fixed synchronization with models using `default_scope`.

## 1.0.3
  * [feature] Add globalized_attributes for handling translated attributes
    with Globalize

## 1.0.2
  * [feature] .reset_synced added, allows to force syncing all local objects on
    the next synchronization. It simply nullifies synced_all_at column.

## 1.0.1
  * [improvement] Options keys can be given as strings
  * [bugfix] Fixed case when `remote:` options is nil, API request is then performed

## 1.0.0

  * [improvement] Mapper can be defined after synced method - using a block
    `synced mapper: -> { Mapper }`.
  * [improvement] `remove:` option can be defined on synced level.
  * [improvement] `include` option can be defined on synced level.
  * [feature] `fields:` option can be specified for fetching only selected
      fields. It's a way to make responses from API smaller. It works on both `synced` and `synchronize` levels.
  * [improvement] Options passed to `synced` and `synchronize` are not
      validated so it's impossible to provide not existing option.
  * [improvement] Completed README
