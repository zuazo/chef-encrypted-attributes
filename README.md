# Chef-Encrypted-Attributes
[![Gem Version](http://img.shields.io/gem/v/chef-encrypted-attributes.svg?style=flat)](http://badge.fury.io/rb/chef-encrypted-attributes)
[![GitHub](http://img.shields.io/badge/github-zuazo/chef--encrypted--attributes-blue.svg?style=flat)](https://github.com/zuazo/chef-encrypted-attributes)
[![License](https://img.shields.io/github/license/zuazo/chef-encrypted-attributes.svg?style=flat)](#license-and-author)

[![Dependency Status](http://img.shields.io/gemnasium/zuazo/chef-encrypted-attributes.svg?style=flat)](https://gemnasium.com/zuazo/chef-encrypted-attributes)
[![Code Climate](http://img.shields.io/codeclimate/github/zuazo/chef-encrypted-attributes.svg?style=flat)](https://codeclimate.com/github/zuazo/chef-encrypted-attributes)
[![Build Status](http://img.shields.io/travis/zuazo/chef-encrypted-attributes.svg?style=flat)](https://travis-ci.org/zuazo/chef-encrypted-attributes)
[![Coverage Status](http://img.shields.io/coveralls/zuazo/chef-encrypted-attributes.svg?style=flat)](https://coveralls.io/r/zuazo/chef-encrypted-attributes?branch=master)
[![Inline docs](http://inch-ci.org/github/zuazo/chef-encrypted-attributes.svg?branch=master&style=flat)](http://inch-ci.org/github/zuazo/chef-encrypted-attributes)

[Chef](https://www.chef.io/) plugin to add Node encrypted attributes support using client keys.

We recommend using the [`encrypted_attributes`](https://supermarket.chef.io/cookbooks/encrypted_attributes) cookbook for easy installation.

## Description

Node attributes are encrypted using chef client and user keys with public key infrastructure (PKI). You can choose which clients, nodes or users will be able to read the attribute.

*Chef Nodes* with read access can be specified using a `node_search` query. In case new nodes are added or removed, the data will be re-encrypted in the next *Chef Run* of the encrypting node (using the `#update` method shown below). Similarly, a `client_search` query can be used to allow *Chef Clients* to read the attribute.

## Requirements

* Ruby `>= 2.0`
* Chef Client `~> 11.8`
* yajl_ruby `~> 1.1` or ffi_yajl `>= 1.0, <3.0` (included with Chef)
* If you want to use protocol version 2 to use [GCM](http://en.wikipedia.org/wiki/Galois/Counter_Mode) (disabled by default):
 * Ruby `>= 2`.
 * OpenSSL `>= 1.0.1`.

## Usage in Recipes

Before reading all the documentation below, we recommend you take a look at the [`encrypted_attributes` cookbook's helper libraries](https://github.com/zuazo/encrypted_attributes-cookbook#helper-libraries). Those libraries are easier to use than the underlying API and cover the most common use cases.

### Installing and Including the Gem

You need to install and include the `chef-encrypted-attributes` gem before using encrypted attributes inside a cookbook.

```ruby
chef_gem 'chef-encrypted-attributes'
require 'chef/encrypted_attributes'
```

### Typical Example

In the following example we save a simple FTP user password.

```ruby
chef_gem 'chef-encrypted-attributes'
require 'chef/encrypted_attributes'

# include the #secure_password method
Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

if Chef::EncryptedAttribute.exist?(node['myapp']['ftp_password'])
  # update with the new keys
  Chef::EncryptedAttribute.update(node.set['myapp']['ftp_password'])

  # read the password
  ftp_pass = Chef::EncryptedAttribute.load(node['myapp']['ftp_password'])
else
  # create the password and save it
  ftp_pass = secure_password
  node.set['myapp']['ftp_password'] = Chef::EncryptedAttribute.create(ftp_pass)
end

# use `ftp_pass` for something here ...
```

**Note:** This example requires the [`openssl`](https://supermarket.chef.io/cookbooks/openssl) cookbook.

### Minimal Write Only Example

In this example we only need to save some data from the local node and read it from another:

```ruby
chef_gem 'chef-encrypted-attributes'
require 'chef/encrypted_attributes'

# Allow all admin clients to read the attributes encrypted by me
Chef::Config[:encrypted_attributes][:client_search] = 'admin:true'

# Allow all webapp nodes to read the attributes encrypted by me
Chef::Config[:encrypted_attributes][:node_search] = 'role:webapp'

if Chef::EncryptedAttribute.exist?(node['myapp']['encrypted_data'])
  # we can used #load here as above if we need the `encrypted_data` outside
  # this `if`

  # update with the new keys
  Chef::EncryptedAttribute.update(node.set['myapp']['encrypted_data'])
else
  # create the data, encrypt and save it
  data_to_encrypt = # ....
  node.set['myapp']['encrypted_data'] =
    Chef::EncryptedAttribute.create(data_to_encrypt)
end
```

Then we can read this attribute from another allowed node (a `'role:webapp'` node):

```ruby
include_recipe 'encrypted_attributes'
# Expose the public key for encryption
include_recipe 'encrypted_attributes::expose_key'

if Chef::EncryptedAttribute.exist_on_node?(
     'random.example.com', %w(myapp encrypted_data)
   )
  data = Chef::EncryptedAttribute.load_from_node(
    'random.example.com', %w(myapp encrypted_data)
  )

  # use `data` for something here ...
end
```

**Note:** Be careful when using `#exist_on_node?` and `#load_from_node` and remember passing the attribute path to read as **Array of Strings** ~~instead of using `node[...]` (which points to the local node)~~.

### Example Using User Keys Data Bag

Suppose we want to store users public keys in a data bag and give them access to the attributes. This can be a workaround for the [Chef Users Limitation](#chef-user-keys-access-limitation) problem.

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
chef_gem 'chef-encrypted-attributes'
require 'chef/encrypted_attributes'

chef_users = Chef::DataBagItem.load('global_data_bag', 'chef_users')
# remove the data bag "id" to avoid to confuse it with a user:
chef_users.delete('id')

Chef::Log.debug(
  "Chef Users able to read the Encrypted Attributes: #{chef_users.keys.inspect}"
)
Chef::Config[:encrypted_attributes][:keys] = chef_users.values

# if Chef::EncryptedAttribute.exist?(...)
#   Chef::EncryptedAttribute.update(...)
# else
#   node.set[...][...] = Chef::EncryptedAttribute.create(...)
# ...
```

**Note:** This data bag does **not** need to be **encrypted**, because it only stores **public keys**.

## Chef::EncryptedAttribute API

See the [API documentation](http://www.rubydoc.info/gems/chef-encrypted-attributes/Chef/EncryptedAttribute/API.html) for a more detailed information about `Chef::EncryptedAttribute` class and its methods.

## Chef User Keys Access Limitation

Keep in mind that, from a Chef Node, *Chef User* *public keys* are inaccessible. So you have to pass them in raw mode in the recipe if you need any *Chef User* to be able to use the encrypted attributes (this is **required for** example to use the **knife commands** included in this gem, as knife is usually used by *Chef Users*). Summarizing, Chef Node inside a recipe (using its *Chef Client* key) will not be able to retrieve the *Chef Users* *public keys*, so you need to pass them using the `[:keys]` configuration value.

Chef Nodes (Clients) with *admin* privileges do have access to user public keys, but in most cases this is not a recommended practice.

See the [Example Using User Keys Data Bag](#example-using-user-keys-data-bag) section for a workaround. You can use the [`encrypted_attributes::users_data_bag`](https://supermarket.chef.io/cookbooks/encrypted_attributes#encrypted_attributes::users_data_bag) recipe for this.

**Note:** *Chef Clients* usually are Chef Nodes and *chef-validation*/*chef-webui* keys. *Chef Users* usually are knife users. The main difference between *Chef Users* and *Chef Clients* is that the former are able to log in via *web-ui* (has a password).

## Chef Client Keys Access Limitation

*Chef Client* *public keys* has a [similar problem to the user keys](#chef-user-keys-access-limitation), you cannot retrieve them from a Chef Node.

To fix this limitation you should expose de *Chef Client* *public key* in the `node['public_key']` attribute. You can include the [`encrypted_attributes::expose_key`](https://supermarket.chef.io/cookbooks/encrypted_attributes#encrypted_attributes::expose_key) recipe for this. You need to include this recipe in the *Chef Nodes* that require read privileges on the encrypted attributes.

Exposing the public key through attributes should not be considered a security breach, so it's not a problem to include it on all machines.

## Maximum Number of Nodes

This gem is ready to be used with Chef Servers that have less than `1000` nodes by default. You can increase this limit setting the `search_max_rows` configuration option:

```ruby
Chef::Config[:encrypted_attributes][:search_max_rows] = 50_000
```

## Knife Commands

See the [KNIFE.md](http://www.rubydoc.info/gems/chef-encrypted-attributes/file/KNIFE.md) file.

## Internal Low Level Documentation

The cryptographic systems used are documented in the following classes:

* [EncryptedMash](http://www.rubydoc.info/gems/chef-encrypted-attributes/Chef/EncryptedAttribute/EncryptedMash)
 * [EncryptedMash::Version0](http://www.rubydoc.info/gems/chef-encrypted-attributes/Chef/EncryptedAttribute/EncryptedMash/Version0)
 * [EncryptedMash::Version1](http://www.rubydoc.info/gems/chef-encrypted-attributes/Chef/EncryptedAttribute/EncryptedMash/Version1)
 * [EncryptedMash::Version2](http://www.rubydoc.info/gems/chef-encrypted-attributes/Chef/EncryptedAttribute/EncryptedMash/Version2)

See the [official gem documentation](http://www.rubydoc.info/gems/chef-encrypted-attributes/) for more information.

## Using Signed Gems

The `chef-encrypted-attributes` gem is cryptographically signed by Onddo Labs's certificate, which identifies as *xabier@zuazo.org*. You can obtain the official signature here:

    https://raw.github.com/zuazo/chef-encrypted-attributes/master/certs/xabier_zuazo.crt

To be sure the gem you install has not been tampered with:

    $ gem cert --add <(curl -Ls https://raw.github.com/zuazo/chef-encrypted-attributes/master/certs/xabier_zuazo.crt)
    $ gem install chef-encrypted-attributes -P MediumSecurity

The *MediumSecurity* trust profile will verify signed gems, but allow the installation of unsigned dependencies. This is necessary because not all of `chef-encrypted-attributes`'s dependencies are signed, so we cannot use *HighSecurity*.

We recommend to remove our certificate after the gem has been successfully verified and installed:

    $ gem cert --remove '/cn=xabier/dc=zuazo/dc=org'

## Security Notes

All the cryptographic systems and algorithms used by `chef-encrypted-attributes` are carefully described in the [internal documentation](#internal-low-level-documentation) for public review. The code was originally based on *Encrypted Data Bags* and [chef-vault](https://github.com/Nordstrom/chef-vault) implementations, then improved.

Still, this gem should be considered experimental until audited by professional cryptographers.

## Reporting Security Problems

If you have discovered a bug in `chef-encrypted-attributes` of a sensitive nature, i.e.  one which can compromise the security of `chef-encrypted-attributes` users, you can report it securely by sending a GPG encrypted message. Please use the following key:

    https://raw.github.com/zuazo/chef-encrypted-attributes/master/zuazo.gpg

The key fingerprint is (or should be):

    ADAE EEFC BD78 6CBB B76B  1662 2195 FF19 5324 14AB

## Testing

See [TESTING.md](https://github.com/zuazo/chef-encrypted-attributes/blob/master/TESTING.md).

## Contributing

Please do not hesitate to [open an issue](https://github.com/zuazo/chef-encrypted-attributes/issues/new) with any questions or problems.

See [CONTRIBUTING.md](https://github.com/zuazo/chef-encrypted-attributes/blob/master/CONTRIBUTING.md).

## TODO

See [TODO.md](https://github.com/zuazo/chef-encrypted-attributes/blob/master/TODO.md).

## License and Author

|                      |                                          |
|:---------------------|:-----------------------------------------|
| **Author:**          | [Xabier de Zuazo](https://github.com/zuazo) (<xabier@zuazo.org>)
| **Contributor:**     | [Josh Kalderimis](https://github.com/joshk)
| **Contributor:**     | [Crystal Hsiung](https://github.com/chhsiung)
| **Contributor:**     | [Lisa Danz](https://github.com/ldanz)
| **Copyright:**       | Copyright (c) 2016 Xabier de Zuazo
| **Copyright:**       | Copyright (c) 2014-2015 Onddo Labs, SL.
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
