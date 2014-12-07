# Chef-Encrypted-Attributes
[![Gem Version](http://img.shields.io/gem/v/chef-encrypted-attributes.svg?style=flat)](http://badge.fury.io/rb/chef-encrypted-attributes)
[![Dependency Status](http://img.shields.io/gemnasium/onddo/chef-encrypted-attributes.svg?style=flat)](https://gemnasium.com/onddo/chef-encrypted-attributes)
[![Code Climate](http://img.shields.io/codeclimate/github/onddo/chef-encrypted-attributes.svg?style=flat)](https://codeclimate.com/github/onddo/chef-encrypted-attributes)
[![Build Status](http://img.shields.io/travis/onddo/chef-encrypted-attributes.svg?style=flat)](https://travis-ci.org/onddo/chef-encrypted-attributes)
[![Coverage Status](http://img.shields.io/coveralls/onddo/chef-encrypted-attributes.svg?style=flat)](https://coveralls.io/r/onddo/chef-encrypted-attributes?branch=master)

[Chef](http://www.getchef.com) plugin to add Node encrypted attributes support using client keys.

We recommend using the [encrypted_attributes cookbook](http://community.opscode.com/cookbooks/encrypted_attributes) for easy installation.

## Description

Node attributes are encrypted using chef client and user keys with public key infrastructure (PKI). You can choose which clients, nodes or users will be able to read the attribute.

*Chef Nodes* with read access can be specified using a `node_search` query. In case new nodes are added or removed, the data will be re-encrypted in the next *Chef Run* of the encrypting node (using the `#update` method shown below). Similarly, a `client_search` query can be used to allow *Chef Clients* to read the attribute.

## Requirements

* Ruby `>= 1.9`
* Chef Client `~> 11.4`
* ffi_yajl `~> 1.0` (included with Chef)
* If you want to use protocol version 2 to use [GCM](http://en.wikipedia.org/wiki/Galois/Counter_Mode) (disabled by default):
 * Ruby `>= 2`.
 * OpenSSL `>= 1.0.1`.

## Usage in Recipes

### Installing and Including the Gem

You need to install and include the `chef-encrypted-attributes` gem before using encrypted attributes inside a cookbook.

```ruby
chef_gem "chef-encrypted-attributes"
require "chef/encrypted_attributes"
```

### Typical Example

In the following example we save a simple FTP user password.

```ruby
chef_gem "chef-encrypted-attributes"
require "chef/encrypted_attributes"

Chef::Recipe.send(:include, Opscode::OpenSSL::Password) # include the #secure_password method

if Chef::EncryptedAttribute.exist?(node["myapp"]["ftp_password"])
  # update with the new keys
  Chef::EncryptedAttribute.update(node.set["myapp"]["ftp_password"])

  # read the password
  ftp_pass = Chef::EncryptedAttribute.load(node["myapp"]["ftp_password"])
else
  # create the password and save it
  ftp_pass = secure_password
  node.set["myapp"]["ftp_password"] = Chef::EncryptedAttribute.create(ftp_pass)
end

# use `ftp_pass` for something here ...
```

**Note:** This example requires the [openssl](http://community.opscode.com/cookbooks/openssl) cookbook.

### Minimal Write Only Example

In this example we only need to save some data from the local node and read it from another:

```ruby
chef_gem "chef-encrypted-attributes"
require "chef/encrypted_attributes"

# Allow all admin clients to read the attributes encrypted by me
Chef::Config[:encrypted_attributes][:client_search] = "admin:true"

# Allow all webapp nodes to read the attributes encrypted by me
Chef::Config[:encrypted_attributes][:node_search] = "role:webapp"

if Chef::EncryptedAttribute.exist?(node["myapp"]["encrypted_data"])
  # when can used #load here as above if we need the `encrypted_data` outside this `if`

  # update with the new keys
  Chef::EncryptedAttribute.update(node.set["myapp"]["encrypted_data"])
else
  # create the data, encrypt and save it
  data_to_encrypt = # ....
  node.set["myapp"]["encrypted_data"] = Chef::EncryptedAttribute.create(data_to_encrypt)
end
```

Then we can read this attribute from another allowed node (a `"role:webapp"` node):

```ruby
include_recipe 'encrypted_attributes'
# Expose the public key for encryption
include_recipe 'encrypted_attributes::expose_key'

if Chef::EncryptedAttribute.exist_on_node?("random.example.com", ["myapp", "encrypted_data"])
  data = Chef::EncryptedAttribute.load_from_node("random.example.com", ["myapp", "encrypted_data"])

  # use `data` for something here ...
end
```

**Note:** Be careful when using `#exist_on_node?` and `#load_from_node` and remember passing the attribute path to read as **Array of Strings** ~~instead of using `node[...]` (which points to the local node)~~.

### Example Using User Keys Data Bag

Suppose we want to store users public keys in a data bag and give them access to the attributes. This can be a workaround for the [Chef Users Limitation](README.md#chef-user-keys-access-limitation) problem.

You need to create a Data Bag Item with a content similar to the following:

```json
{
  "id": "chef_users",
  "bob": "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFA...",
  "alice": "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFA..."
}
```

This data bag will contain the user public keys retrieved with `knife user show USER -a public_key -f json`.

Then, from a recipe, you can read this user keys and allow them to read the attributes.

```ruby
chef_gem "chef-encrypted-attributes"
require "chef/encrypted_attributes"

chef_users = Chef::DataBagItem.load("global_data_bag", "chef_users")
chef_users.delete("id") # remove the data bag "id" to avoid to confuse it with a user

Chef::Log.debug("Admin users able to read the Encrypted Attributes: #{chef_users.keys.inspect}")
Chef::Config[:encrypted_attributes][:keys] = chef_users.values

# if Chef::EncryptedAttribute.exist?(...)
#   Chef::EncryptedAttribute.update(...)
# else
#   node.set[...][...] = Chef::EncryptedAttribute.create(...)
# ...
```

**Note:** This data bag does **not** need to be **encrypted**, because it only stores **public keys**.

## Chef::EncryptedAttribute API

See the [API.md](API.md) file for a more detailed documentation about `Chef::EncryptedAttribute` class and its methods.

## Chef User Keys Access Limitation

Keep in mind that, from a Chef Node, *Chef User* *public keys* are inaccessible. So you have to pass them in raw mode in the recipe if you need any *Chef User* to be able to use the encrypted attributes (this is **required for** example to use the **knife commands** included in this gem, as knife is usually used by *Chef Users*). Summarizing, Chef Node inside a recipe (using its *Chef Client* key) will not be able to retrieve the *Chef Users* *public keys*, so you need to pass them using the `[:keys]` configuration value.

Chef Nodes (Clients) with *admin* privileges do have access to user public keys, but in most cases this is not a recommended practice.

See the [Example Using User Keys Data Bag](README.md#example-using-user-keys-data-bag) section for a workaround. You can use the [`encrypted_attributes::users_data_bag`](https://supermarket.chef.io/cookbooks/encrypted_attributes#encrypted_attributes::users_data_bag) recipe for this.

**Note:** *Chef Clients* usually are Chef Nodes and *chef-validation*/*chef-webui* keys. *Chef Users* usually are knife users. The main difference between *Chef Users* and *Chef Clients* is that the former are able to log in via *web-ui* (has a password).

## Chef Client Keys Access Limitation

*Chef Client* *public keys* has a [similar problem to the user keys](README.md#chef-user-keys-access-limitation), you cannot retrieve them from a Chef Node.

To fix this limitation you should expose de *Chef Client* *public key* in the `node['public_key']` attribute. You can include the [`encrypted_attributes::expose_key`](https://supermarket.chef.io/cookbooks/encrypted_attributes#encrypted_attributes::expose_key)` recipe for this. You need to include this recipe in the *Chef Nodes* that require read privileges on the encrypted attributes.

Exposing the public key through attributes should not be considered a security breach, so it's not a problem to include it on all machines.

## Knife Commands

There are multiple commands to read, create and modify the encrypted attributes. All the commands will grant access privileges to the affected node by default (encrypted attributes are written in Node Attributes). But you will not be allowed to access them by default, so remember to give your own knife user privileges before creating or saving the attribute.

The `ATTRIBUTE` name must be specified using *dots* notation. For example, for `node['encrypted']['attribute']`, you must specify `"encrypted.attribute"` as knife argument. If the attribute key has a *dot* in its name, you must escape it. For example: `"encrypted.attribute\.with\.dots"`.

Read the [Chef Users Limitation](README.md#chef-user-keys-access-limitation) caveat before trying to use any knife command.

### Installing the Required Gem

You need to install the `chef-encrypted-attributes` gem before using this knife commands.

    $ gem install chef-encrypted-attributes

### knife.rb

Some configuration values can be set in your local `knife.rb` configuration file inside the `knife[:encrypted_attributes]` configuraiton space. For example:

```ruby
knife[:encrypted_attributes][:users] = '*' # allow access to all knife users
```

See the [API Configuration](API.md#configuration) section for more configuration values.

### knife encrypted attribute show

Shows the decrypted attribute content.

    $ knife encrypted attribute show NODE ATTRIBUTE (options)

For example:

    $ knife encrypted attribute show ftp.example.com myapp.ftp_password

### knife encrypted attribute create

Creates an encrypted attribute in a node. The attribute cannot already exist.

    $ knife encrypted attribute create NODE ATTRIBUTE (options)

If the input is in JSON format (`-i`), you can create a JSON in *quirk* mode like `false`, `5` or `"some string"`. You don't need to create an Array or a Hash as the JSON standard forces.

For example:

    $ export EDITOR=vi
    $ knife encrypted attribute create ftp.example.com myapp.ftp_password \
        -U bob -U alice

### knife encrypted attribute update

Updates who can read the attribute (for `:client_search` and `:node_search` changes).

    $ knife encrypted attribute update NODE ATTRIBUTE (options)

**You must be careful to pass the same privilege arguments that you used in its creation** (this will surely be fixed in a future).

For example:

    $ knife encrypted attribute update ftp.example.com myapp.ftp_password \
        --client-search admin:true \
        --node-search role:webapp \
        -U bob -U alice

### knife encrypted attribute edit

Edits an existing encrypted attribute. The attribute must exist.

    $ knife encrypted attribute edit NODE ATTRIBUTE (options)

If the input is in JSON format (`-i`), you can create a JSON in *quirk* mode like `false`, `5` or `"some string"`. You don't need to create an Array or a Hash as the JSON standard forces.

**You must be careful to pass the same privilege arguments that you used in its creation** (this will surely be fixed in a future).

For example:

    $ export EDITOR=vi
    $ knife encrypted attribute edit ftp.example.com myapp.ftp_password \
        --client-search admin:true \
        --node-search role:webapp \
        -U bob -U alice

### knife encrypted attribute delete

Deletes an existing attribute. If you have no privileges to read it, you must use the `--force` flag.

    $ knife encrypted attribute delete NODE ATTRIBUTE (options)

For example:

    $ knife encrypted attribute delete ftp.example.com myapp.ftp_password --force

### Knife Options

<table>
  <tr>
    <th>Short</th>
    <th>Long</th>
    <th>Description</th>
    <th>Valid Values</th>
    <th>Sub-Commands</th>
  </tr>
  <tr>
    <td>&nbsp;</td>
    <td>--encrypted-attribute-version</td>
    <td>Encrypted Attribute protocol version to use</td>
    <td>"0", "1" <em>(default)</em>, "2"</td>
    <td>create, edit, update</td>
  </tr>
  <tr>
    <td>-P</td>
    <td>--disable-partial-search</td>
    <td>Disable partial search</td>
    <td>&nbsp;</td>
    <td>create, edit, update</td>
  </tr>
  <tr>
    <td>-C</td>
    <td>--client-search</td>
    <td>Client search query. Can be specified multiple times</td>
    <td>&nbsp;</td>
    <td>create, edit, update</td>
  </tr>
  <tr>
    <td>-N</td>
    <td>--node-search</td>
    <td>Node search query. Can be specified multiple times</td>
    <td>&nbsp;</td>
    <td>create, edit, update</td>
  </tr>
  <tr>
    <td>-U</td>
    <td>--user</td>
    <td>User name to allow access to. Can be specified multiple times</td>
    <td>&nbsp;</td>
    <td>create, edit, update</td>
  </tr>
  <tr>
    <td>-i</td>
    <td>--input-format</td>
    <td>Input (<em>EDITOR</em>) format</td>
    <td>"plain" <em>(default)</em>, "json"</td>
    <td>create, edit</td>
  </tr>
  <tr>
    <td>-f</td>
    <td>--force</td>
    <td>Force the attribute deletion even if you cannot read it</td>
    <td>&nbsp;</td>
    <td>delete</td>
  </tr>
</table>

## Internal Documentation

See the [INTERNAL.md](INTERNAL.md) file for a more low level documentation.

## Using Signed Gems

The `chef-encrypted-attributes` gem is cryptographically signed by Onddo Labs's certificate, which identifies as *team@onddo.com*. You can obtain the official signature here:

    https://raw.github.com/onddo/chef-encrypted-attributes/master/certs/team_onddo.crt

To be sure the gem you install has not been tampered with:

    $ gem cert --add <(curl -Ls https://raw.github.com/onddo/chef-encrypted-attributes/master/certs/team_onddo.crt)
    $ gem install chef-encrypted-attributes -P MediumSecurity

The *MediumSecurity* trust profile will verify signed gems, but allow the installation of unsigned dependencies. This is necessary because not all of `chef-encrypted-attributes`'s dependencies are signed, so we cannot use *HighSecurity*.

We recommend to remove our certificate after the gem has been successfully verified and installed:

    $ gem cert --remove '/cn=team/dc=onddo/dc=com'

## Security Notes

All the cryptographic systems and algorithms used by `chef-encrypted-attributes` are carefully described in the [internal documentation](INTERNAL.md) for public review. The code was originally based on *Encrypted Data Bags* and [chef-vault](https://github.com/Nordstrom/chef-vault) implementations, then improved.

Still, this gem should be considered experimental until audited by professional cryptographers.

## Reporting Security Problems

If you have discovered a bug in `chef-encrypted-attributes` of a sensitive nature, i.e.  one which can compromise the security of `chef-encrypted-attributes` users, you can report it securely by sending a GPG encrypted message. Please use the following key:

    https://raw.github.com/onddo/chef-encrypted-attributes/master/zuazo.gpg

The key fingerprint is (or should be):

    8EFA 5B17 7275 5F1F 42B2  26B4 8E18 8B67 9DE1 9468

## Testing

See [TESTING.md](TESTING.md).

## Contributing

Please do not hesitate to [open an issue](https://github.com/onddo/chef-encrypted-attributes/issues/new) with any questions or problems.

See [CONTRIBUTING.md](CONTRIBUTING.md).

## TODO

See [TODO.md](TODO.md).

## License and Author

|                      |                                          |
|:---------------------|:-----------------------------------------|
| **Author:**          | [Xabier de Zuazo](https://github.com/zuazo) (<xabier@onddo.com>)
| **Copyright:**       | Copyright (c) 2014 Onddo Labs, SL. (www.onddo.com)
| **License:**         | Apache License, Version 2.0

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    
        http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
