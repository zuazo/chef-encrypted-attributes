# Knife Commands

There are multiple commands to read, create and modify the encrypted attributes. All the commands will grant access privileges to the affected node by default (encrypted attributes are written in Node Attributes). But you will not be allowed to access them by default, so remember to give your own knife user privileges before creating or saving the attribute.

The `ATTRIBUTE` name must be specified using *dots* notation. For example, for `node['encrypted']['attribute']`, you must specify `"encrypted.attribute"` as knife argument. If the attribute key has a *dot* in its name, you must escape it. For example: `"encrypted.attribute\.with\.dots"`.

Read the [Chef Users Limitation](http://zuazo.github.io/chef-encrypted-attributes/#chef-user-keys-access-limitation) caveat before trying to use any knife command.

## Installing the Required Gem

You need to install the `chef-encrypted-attributes` gem before using this knife commands.

    $ gem install chef-encrypted-attributes

## knife.rb

Some configuration values can be set in your local `knife.rb` configuration file inside the `knife[:encrypted_attributes]` configuraiton space. For example:

```ruby
knife[:encrypted_attributes][:users] = '*' # allow access to all knife users
```

See the [API Configuration](http://www.rubydoc.info/gems/chef-encrypted-attributes/Chef/EncryptedAttribute/API.html#Configuration) section for more configuration values.

## knife encrypted attribute show

Shows the decrypted attribute content.

    $ knife encrypted attribute show NODE ATTRIBUTE (options)

For example:

    $ knife encrypted attribute show ftp.example.com myapp.ftp_password

## knife encrypted attribute create

Creates an encrypted attribute in a node. The attribute cannot already exist.

    $ knife encrypted attribute create NODE ATTRIBUTE (options)

If the input is in JSON format (`-i`), you can create a JSON in *quirk* mode like `false`, `5` or `"some string"`. You don't need to create an Array or a Hash as the JSON standard forces.

For example:

    $ export EDITOR=vi
    $ knife encrypted attribute create ftp.example.com myapp.ftp_password \
        -U bob -U alice

## knife encrypted attribute update

Updates who can read the attribute (for `:client_search` and `:node_search` changes).

    $ knife encrypted attribute update NODE ATTRIBUTE (options)

**You must be careful to pass the same privilege arguments that you used in its creation** (this will surely be fixed in a future).

For example:

    $ knife encrypted attribute update ftp.example.com myapp.ftp_password \
        --client-search admin:true \
        --node-search role:webapp \
        -U bob -U alice

## knife encrypted attribute edit

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

## knife encrypted attribute delete

Deletes an existing attribute. If you have no privileges to read it, you must use the `--force` flag.

    $ knife encrypted attribute delete NODE ATTRIBUTE (options)

For example:

    $ knife encrypted attribute delete ftp.example.com myapp.ftp_password --force

## Knife Options

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
