# CHANGELOG for chef-encrypted-attributes

This file is used to list changes made in each version of `chef-encrypted-attributes`.

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
* Added Protocol Version 2 (*disabled by default*): uses [GCM](http://en.wikipedia.org/wiki/Galois/Counter_Mode) as in [Chef 12 Encrypted Data Bags Version 3](https://github.com/opscode/chef/pull/1591).
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
