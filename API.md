# Chef::EncryptedAttribute API Documentation

`Chef::EncryptedAttribute` has some static methods intended to be used from cookbooks.

## Static Methods

### Chef::EncryptedAttribute.load(hs [, config])

Reads an encrypted attribute from a hash, usually a node attribute.

* `hs` - An encrypted hash, usually a node attribute. For example: `node["myapp"]["ftp_password"]`.
* `config` - A configuration hash (optional). For example: `{ :partial_search => false }`.

Returns the attribute in clear text, decrypted.

An exception is thrown if the attribute cannot be decrypted or no encrypted attribute is found.

### Chef::EncryptedAttribute.create(value [, config])

Creates an encrypted attribute. The returned value should be saved in a node attribute, like `node.normal[...] = `.

* `value` - The value to be encrypted. Can be a boolean, a number, a string, an array or a hash (the value will be converted to JSON internally).
* `config` - A configuration hash (optional). For example: `{ :client_search => "admin:true" }`.

Returns the encrypted attribute.

An exception is thrown if any error arises in the encryption process.

### Chef::EncryptedAttribute.update(hs [, config])

Updates who can read the attribute. This is intended to be used to update to the new nodes returned by the `:client_search` or perhaps global configuration changes.

For example, in case new nodes are added or some are removed, and the clients returned by `:client_search` are different, this `#update` method will decrypt the attribute and encrypt it again for the new nodes (or remove the old ones).

If an update is made, the shared secrets are regenerated.

* `hs` - This must be a node encrypted attribute, this attribute will be updated, so it is mandatory to specify the type (usually `normal`). For example: `node.normal["myapp"]["ftp_password"]`.
* `config` - A configuration hash (optional). Surely you want this `#update` method to use the same `config` that the `#create` call.

Returns `true` if the encrypted attribute has been updated, `false` if not.

An exception is thrown if there is any error in the updating process.

### Chef::EncryptedAttribute.exist?(hs)

Checks whether an encrypted attribute exists.

* `hs` - An encrypted hash, usually a node attribute. The attribute type can be specified but is not necessary. For example: `node["myapp"]["ftp_password"]`.

Returns `true` if an encrypted attribute is found, `false` if not.

### Chef::EncryptedAttribute.load_from_node(name, attr_ary [, config])

Reads an encrypted attribute from a remote node.

* `name` - The node name.
* `attr_ary` - The attribute path as *array of strings*. For example: `[ "myapp", "ftp_password" ]`.
* `config` - A configuration hash (optional). For example: `{ :partial_search => false }`.

An exception is thrown if the attribute cannot be decrypted or no encrypted attribute is found.

### Chef::EncryptedAttribute.create_on_node(name, attr_ary, value [, config])

Creates an encrypted attribute on a remote node.

* `name` - The node name.
* `attr_ary` - The attribute path as *array of strings*. For example: `[ "myapp", "ftp_password" ]`.
* `value` - The value to be encrypted. Can be a boolean, a number, a string, an array or a hash (the value will be converted to JSON internally).
* `config` - A configuration hash (optional). For example: `{ :client_search => "admin:true" }`.

An exception is thrown if any error arises in the encryption process.

This method **requires admin privileges**. So in most cases, cannot be used from cookbooks.

### Chef::EncryptedAttribute.update_on_node(name, attr_ary [, config])

Updates who can read the attribute.

* `name` - The node name.
* `attr_ary` - The attribute path as *array of strings*. For example: `[ "myapp", "ftp_password" ]`.
* `config` - A configuration hash (optional). Surely you want this `#update_on_node` method to use the same `config` that the `#create` call.

Returns `true` if the encrypted attribute has been updated, `false` if not.

An exception is thrown if there is any error in the updating process.

This method **requires admin privileges**. So in most cases, cannot be used from cookbooks.

### Chef::EncryptedAttribute.exist_on_node?(name, attr_ary [, config])

Checks whether an encrypted attribute exists in a remote node.

* `name` - The node name.
* `attr_ary` - The attribute path as *array of strings*. For example: `[ "myapp", "ftp_password" ]`.
* `config` - A configuration hash (optional). For example: `{ :partial_search => false }`.

Returns `true` if an encrypted attribute is found, `false` if not.

## Configuration

All the methods read the default configuration from the `Chef::Config[:encrypted_attributes]` hash. Most of methods also support setting some configuration parameters as last argument. Both the global and the method argument configuration will be merged.

If the configuration value to be merged is an array or a hash (for example `keys`), the method argument configuration value has preference over the global configuration. Arrays and hashes are not merged.

Both `Chef::Config[:encrypted_attributes]` and method's `config` parameter should be a hash which may have any of the following keys:

* `:version` - `EncryptedMash` format version to use, by default `1` is used which is recommended. The version `2` uses [GCM](http://en.wikipedia.org/wiki/Galois/Counter_Mode) and probably should be considered the most secure, but it is disabled by default because it has some more requirements:
 * Ruby `>= 2`.
 * OpenSSL `>= 1.0.1`.
* `:partial_search` - Whether to use Chef Server partial search, enabled by default. It may not work in some old versions of Chef Server.
* `:client_search` - Search query for clients allowed to read the encrypted attribute. Can be a simple string or an array of queries to be *OR*-ed.
* `:users` - Array of user names to be allowed to read the encrypted attribute(s). `"*"` to allow access to all users. Keep in mind that only admin clients or admin users are allowed to read user public keys. It is **not recommended** to use this from cookbooks unless you know what you are doing.
* `:keys` - raw RSA public keys to be allowed to read encrypted attributes(s), in PEM (string) format. Can be client public keys, user public keys or any other RSA public key.

For example, to disable Partial Search globally:

```ruby
Chef::Config[:encrypted_attributes][:partial_search] = false

# ftp_pass = Chef::EncryptedAttribute.load(node["myapp"]["ftp_password"])
# ...
```

To disable Partial Search locally:

```ruby
ftp_pass = Chef::EncryptedAttribute.load(node["myapp"]["ftp_password"], { :partial_search => false })
```

To use protocol version 2 globally, which uses [GCM](http://en.wikipedia.org/wiki/Galois/Counter_Mode):

```ruby
Chef::Config[:encrypted_attributes][:version] = 2
# ...
```

If you want to use knife to work with encrypted attributes, surely you will need to save your Chef User public keys in a Data Bag (there is no need to encrypt them because they are public) and add them to the `:keys` configuration option. See the [Example Using User Keys Data Bag](README.md#example-using-user-keys-data-bag) in the README for more information on this.

## Caches

This API uses some LRU caches to avoid making many requests to the Chef Server. All the caches are global and has the following methods:

* `max_size` - Gets or sets the cache maximum item size.
* `clear` - To empty the cache.
* `[]` - To read a cache value (used internally).
* `[]=` - To set a cache value (used internally).

This are the currently available caches:

* `Chef::EncryptedAttribute::RemoteClients.cache` - Caches the `:client_search` query results (max_size: `1024`).
* `Chef::EncryptedAttribute::RemoteUsers.cache` - Caches the Chef Users public keys (max_size: `1024`).
* `Chef::EncryptedAttribute::RemoteNode.cache` - Caches the node (encrypted) attributes. Disabled by default (max_size: `0`).

### Clear All the Caches

You can clear all the caches with the following code:

```ruby
Chef::EncryptedAttribute::RemoteClients.cache.clear
Chef::EncryptedAttribute::RemoteUsers.cache.clear
Chef::EncryptedAttribute::RemoteNode.cache.clear
```

### Disable All the Caches

You can disable all the caches with the following code:

```ruby
Chef::EncryptedAttribute::RemoteClients.cache.max_size(0)
Chef::EncryptedAttribute::RemoteUsers.cache.max_size(0)
Chef::EncryptedAttribute::RemoteNode.cache.max_size(0)
```
