# Chef-Encrypted-Attributes

[Chef](http://www.getchef.com) plugin to add Node encrypted attributes support using client keys.

## Description

Node attributes are encrypted using chef client and user keys with public key infrastructure (PKI). You can choose which clients, nodes or users will be able to read the attribute.

Node clients with read access can be specified using a `client_search` query. In case new nodes are added or removed, the data will be re-encrypted in the next *Chef Run* of the encrypting node (using the `#update` method shown below).

## Requirements

* Ruby `>= 1.9`
* Chef `>= 11.4`
* yajl-ruby `~> 1.1` (included with Chef)

## Usage in Recipes

### Installing and Including the Gem

You need to install and include the `chef-encrypted-attributes` gem before using encrypted attributes inside a cookbook.

```ruby
chef_gem "chef-encrypted-attributes"
require "chef-encrypted-attributes"
```

### Typical Example

In the following example we save a simple FTP user password.

```ruby
chef_gem "chef-encrypted-attributes"
require "chef-encrypted-attributes"

Chef::Recipe.send(:include, Opscode::OpenSSL::Password) # include the #secure_password method

if Chef::EncryptedAttribute.exists?(node["myapp"]["ftp_password"])
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
require "chef-encrypted-attributes"

# Allow all webapp nodes to read the attributes encrypted by me
Chef::Config[:encrypted_attributes][:client_search] = "role:webapp"

if Chef::EncryptedAttribute.exists?(node["myapp"]["encrypted_data"])
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
chef_gem "chef-encrypted-attributes"
require "chef-encrypted-attributes"

if Chef::EncryptedAttribute.exists_on_node?("random.example.com", ["myapp", "encrypted_data"])
  data = Chef::EncryptedAttribute.load_from_node("random.example.com", ["myapp", "encrypted_data"])

  # use `data` for something here ...
end
```

**Note:** Be careful when using `#exists_on_node?` and `#load_from_node` and remember passing the attribute path to read as **Array of Strings** ~~instead of using `node[...]` (which points to the local node)~~.

### Example Using User Keys Data Bag

Suppose we want to store users public keys in a data bag and give them access to the attributes. This can be a workaround for the [Chef Users Limitation](README.md#chef-users-limitation) problem.

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
require "chef-encrypted-attributes"

chef_users = Chef::DataBagItem.load("global_data_bag", "chef_users")
chef_users.delete("id") # remove the data bag "id" to avoid to confuse it with a user

Chef::Log.debug("Admin users able to read the Encrypted Attributes: #{chef_users.keys.inspect}")
Chef::Config[:encrypted_attributes][:keys] = chef_users.values

# if Chef::EncryptedAttribute.exists_on_node?(...)
#   Chef::EncryptedAttribute.update(...)
# else
#   node.set[...][...] = Chef::EncryptedAttribute.create(...)
# ...
```

**Note:** This data bag does **not** need to be **encrypted**, because it only stores **public keys**.

## Chef::EncryptedAttribute API

See the [API.md](API.md) file for a more detailed documentation about `Chef::EncryptedAttribute` class and its methods.

## Chef Users Limitation

Keep in mind that, from a Chef Node, *Chef User* *public keys* are inaccessible. So you have to pass them in raw mode in the recipe if you need any *Chef User* to be able to use the encrypted attributes (this is **required for** example to use the **knife commands** included in this gem, as knife is usually used by *Chef Users*). Summarizing, Chef Node inside a recipe (using its *Chef Client* key) will not be able to retrieve the *Chef Users* *public keys*, so you need to pass them using the `[:keys]` configuration value.

Chef Nodes (Clients) with *admin* privileges do have access to user public keys, but in most cases this is not a recommended practice.

*Chef Client* *public keys* do not have this problem, you can retrieve them from any place without limitation. You can use knife with an *Chef Admin Client* instead of a *Chef Admin User* key, but this is not common.

See the [Example Using User Keys Data Bag](README.md#example-using-user-keys-data-bag) section for a workaround.

**Note:** *Chef Clients* usually are Chef Nodes and *chef-validation*/*chef-webui* keys. *Chef Users* usually are knife users. The main difference between *Chef Users* and *Chef Clients* is that the former are able to log in via *web-ui* (has a password).

## Knife Commands

There are multiple commands to read, create and modify the encrypted attributes. All the commands will grant access privileges to the affected node by default (encrypted attributes are written in Node Attributes). But you will not be allowed to access them by default, so remember to give your own knife user privileges before creating or saving the attribute.

The `ATTRIBUTE` name must be specified using *dots* notation. For example, for `node['encrypted']['attribute']`, you must specify `"encrypted.attribute"` as knife argument. If the attribute key has a *dot* in its name, you must escape it. For example: `"encrypted.attribute\.with\.dots"`.

Read the [Chef Users Limitation](README.md#chef-users-limitation) caveat before trying to use any knife command.

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

Updates who can read the attribute (for `:client_search` changes).

    $ knife encrypted attribute update NODE ATTRIBUTE (options)

**You must be careful to pass the same privilege arguments that you used in its creation** (this will surely be fixed in a future).

For example:

    $ knife encrypted attribute update ftp.example.com myapp.ftp_password \
        --client-search admin:true \
        --client-search role:webapp \
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
        --client-search role:webapp \
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
    <td>"0", "1" <em>(default)</em></td>
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

## Contributing

1. Fork the repository on Github.
2. Create a named feature branch (like `add_component_x`).
3. Write tests for your change.
4. Write your change.
5. Run the tests, ensuring they all pass (try as much as possible not to reduce coverage).
6. Submit a Pull Request using Github.

See the [TESTING.md](TESTING.md) file to know how to run the tests properly.

You can also see the [TODO.md](TODO.md) file if you're looking for inspiration.

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
