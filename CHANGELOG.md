  * [feature] Allow to scope synchronize per rental

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
