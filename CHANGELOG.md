# CHANGELOG for chef-encrypted-attributes

This file is used to list changes made in each version of `chef-encrypted-attributes`.

## 0.3.0:

* gemspec: added the missing CONTRIBUTING.md file
* README: replaced exist_on_node? by exist? in users_data_bag example
* Added the required `:node_search` option (fixes the `"role:..."` examples).

## 0.2.0:

* Deprecate `#exists?` methods in favor of `#exist?` methods
* Fixed all RSpec deprecation warnings
* Added Protocol Version 2 (*disabled by default*): uses [GCM](http://en.wikipedia.org/wiki/Galois/Counter_Mode) as in [Chef 12 Encrypted Data Bags Version 3](https://github.com/opscode/chef/pull/1591).
 * Added `RequirementsFailure` exception
* README, CONTRIBUTING, TODO: multiple documentation improvements
 * Added some security related sections to the README
* Added email GPG key
* Added gem signing certificate
* gemspec: added dev dependency versions with pessimistic operator

## 0.1.1:

* gemspec: replaced open-ended chef dependency by `~> 11.4`
* Fixed ruby `1.9.2` decryption (uses `PKCS#1` for public key format)
* README: added `encrypted_attributes` cookbook link
* INTERNAL doc: added `EncryptedMash` class name to the Version0 structure
* Added shields.io badges

## 0.1.0:

* Initial release of `chef-encrypted-attributes`
