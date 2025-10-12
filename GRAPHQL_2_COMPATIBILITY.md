* **warden compatibility**: Fix GraphQL-Ruby 2.x compatibility by replacing warden usage with backward-compatible methods ([#PR-TBD](https://github.com/mondaycom/apollo-federation-ruby/issues/PR-TBD))
  - Fixed `undefined local variable or method 'warden'` error in GraphQL Ruby 2.x
  - Added backward-compatible `fields_for_type` and `root_type_for_operation` methods
  - Updated `entities_field.rb` to use schema.types when warden is not available
  - Maintains full compatibility with both GraphQL Ruby 1.x and 2.x