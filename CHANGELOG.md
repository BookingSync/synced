## 1.0.0.rc2
  * [improvement] Options keys can be given as strings
  * [bugfix] Fixed case when remote: options is nil, API request is then performed

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
