# CHANGELOG for chef-encrypted-attributes

This file is used to list changes made in each version of `chef-encrypted-attributes`.

## 0.9.0 (2016-09-15)

* Remove support for Ruby < `2.0` (**breaking change**).
* Change requirements to Chef `11.8` or higher (**breaking change**).
* Replace depreciated `Chef::REST` with `Chef::ServerAPI` ([issue #6](https://github.com/zuazo/chef-encrypted-attributes/pull/6), thanks to [Eric Blevins](https://github.com/e100)).
* Fix integration and unit tests ([see issue #6](https://github.com/zuazo/chef-encrypted-attributes/pull/6), thanks to [Eric Blevins](https://github.com/e100)).
* Update and fix dependencies in the gemspec ([see issue #6](https://github.com/zuazo/chef-encrypted-attributes/pull/6), thanks to [Eric Blevins](https://github.com/e100)).
* Update chef links to use *chef.io* domain.
* Update contact information and links after migration.
* README: Add GitHub and License badges.

## 0.8.0 (2015-05-22)

* Do not limit `RemoteNode#load_attribute` search result to one row (related to [issue #3](https://github.com/zuazo/chef-encrypted-attributes/pull/3), thanks [Crystal Hsiung](https://github.com/chhsiung) for the help).
* Update opscode and github links to chef.io and chef.

## 0.7.0 (2015-05-20)

* Move chef to dev dependency and remove dynamic dependency installation extension (related to [cookbook issue #2](https://github.com/zuazo/encrypted_attributes-cookbook/pull/2#issuecomment-101454221) and [issue #2](https://github.com/zuazo/chef-encrypted-attributes/pull/2), thanks [Lisa Danz](https://github.com/ldanz) for reporting).
* Fix search by node name to prevent returning incorrect nodes ([issue #3](https://github.com/zuazo/chef-encrypted-attributes/pull/3), thanks [Crystal Hsiung](https://github.com/chhsiung) for the help).
* RuboCop update to `0.31.0`.
* README: Add a link to the cookbook helper libraries.

## 0.6.0 (2015-05-08)

* Conditional gem dependency installation within a gemspec ([issue #2](https://github.com/zuazo/chef-encrypted-attributes/pull/2), thanks [@chhsiung](https://github.com/chhsiung) for the help).
* Choose YAJL library based on chef version ([issue #4](https://github.com/zuazo/chef-encrypted-attributes/pull/4), thanks [Lisa Danz](https://github.com/ldanz)).
* Add doc Rake task to generate the documentation.

## 0.5.0 (2015-04-03)

* `#load_from_node` raises an exception if no ecnrypted attribute is found.
* GemSpec:
  * Fix Ruby < 2 support ([issue #2](https://github.com/zuazo/chef-encrypted-attributes/pull/2), thanks [@chhsiung](https://github.com/chhsiung) for the help).
  * Depend on `ffi-yajl` `< 3` as in Chef.

* Tests:
  * Use the new build environment on Travis ([issue #1](https://github.com/zuazo/chef-encrypted-attributes/pull/1), thanks [Josh Kalderimis](https://github.com/joshk))
  * GemSpec: Update RuboCop to version `0.29.1` (new offenses fixed).

* Documentation:
  * README: Fix testing link.

## 0.4.0 (2014-12-10)

* Add Chef `12` support.
* Read `node['public_key']` instead of client public key when set.
* Add *chef/encrypted_attributes* library file.
 * **Deprecates** *chef-encrypted-attributes* library file.
* Replace `yajl` gem by `ffi_yajl` gem.
* Gemspec: fix Ruby `< 1.9.3` support (mixlib-shellout `< 1.6.1`).
* Rename `InvalidPrivateKey` exception to `InvalidKey`.
* Add UTF-8 encoding header to all files.
* Big code refactor and clean-up.
  * Code refactor all clases.
  * Add `Chef::EncryptedAttribute::API` module.
  * Clean-up Gemspec and Rakefile files code.

* Tests:
 * Review and clean-up all tests.
 * Integrate tests with `should_not` gem.
 * Integrate with RuboCop.
 * Add some knife unit tests.
 * Update tests to RSpec `3.1`.
 * Update tests to chef-zero `3.2`.

* Documentation:
 * Document all classes and integrate them with yard and inch.
 * Add KNIFE.md file.
 * Move INTERNAL.md documentation to gem documentation.
 * Move API.md documentation to gem documentation.
 * README:
  * Multiple fixes and improvements.
  * Use chef.io domain for links.
  * Add codeclimate badge.
  * Add inch-ci documentation badge.
 * Fix CHANGELOG format.
 * CONTRIBUTING: add documetation about documentation.

## 0.3.0 (2014-08-25)

* gemspec: added the missing CONTRIBUTING.md file
* README: replaced exist_on_node? by exist? in users_data_bag example
* Added the required `:node_search` option (fixes the `"role:..."` examples).

## 0.2.0 (2014-08-12)

* Deprecate `#exists?` methods in favor of `#exist?` methods
* Fixed all RSpec deprecation warnings
* Added Protocol Version 2 (*disabled by default*): uses [GCM](http://en.wikipedia.org/wiki/Galois/Counter_Mode) as in [Chef 12 Encrypted Data Bags Version 3](https://github.com/chef/chef/pull/1591).
 * Added `RequirementsFailure` exception
* README, CONTRIBUTING, TODO: multiple documentation improvements
 * Added some security related sections to the README
* Added email GPG key
* Added gem signing certificate
* gemspec: added dev dependency versions with pessimistic operator

## 0.1.1 (2014-05-23)

* gemspec: replaced open-ended chef dependency by `~> 11.4`
* Fixed ruby `1.9.2` decryption (uses `PKCS#1` for public key format)
* README: added `encrypted_attributes` cookbook link
* INTERNAL doc: added `EncryptedMash` class name to the Version0 structure
* Added shields.io badges

## 0.1.0 (2014-05-21)

* Initial release of `chef-encrypted-attributes`
