TODO
====

* Refactor `SearchHelper` class.
* Fix all RuboCop offenses.
* knife encrypted attribute create/edit from file.
* Save config inside encrypted data: `:client_search`, `:node_search` and `:keys` (including user keys).
* Chef internal node attribute integration monkey-patch. It may require some `EncryptedMash` class rewrite or adding some methods.
* Support for Chef `< 11.4` (add `JSONCompat#map_to_rb_obj`, disable `Chef::User` for `< 11.2`, ...).
* Add more info/debug prints.
* Space-optimized `EncryptedMash::Version3` class.
* Tests: Add test helper functions (key generation, ApiClients including priv keys, Node creation...).
* Tests: Add more tests for `EncryptedMash::Version1` and `EncryptedMash::Version2`.
* Tests: Add unit tests for `EncryptedAttribute`.
* Tests: Add unit tests for all knife commands.
* Tests: `raise_error` tests always include regex.
* Add `chef-vault` to benchmarks.
* Signed attributes?
