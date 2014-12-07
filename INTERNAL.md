# Internal Documentation

## EncryptedAttribute Class

This class contains both static and instance level public methods. Internally, all work with `EncryptedMash` object instances.

The **static methods** are intended to be used from Cookbooks. The attributes are encrypted only for the local node by default. The static `*_on_node` methods can be used also, although they have not been designed for this purpose (have not been tested).

The **instance methods** are intended to be used from `knife` or external libraries. Usually only the `*_from_node/*_on_node` instance methods will be used. These methods will grant access only to the remote node by default.

## EncryptedMash Class

This is the most basic encrypted object, which inherits from `Chef::Mash`.

Currently two `EncryptedMash` versions exists. But you can create your own versions and name it with the `Chef::EncryptedAttribute::EncryptedMash::Version` prefix.

### EncryptedMash::Version0

This is the first version, considered old. Uses public key cryptography (PKI) to encrypt the data. There is no shared secret or HMAC for data integrity checking.

#### EncryptedMash::Version0 Structure

If you try to read this encrypted attribute structure, you can see a `Chef::Mash` attribute with the following content:

```
EncryptedMash
└── encrypted_data
    ├── pub_key_hash1: The data encrypted using PKI for the public key 1 (base64)
    ├── pub_key_hash2: The data encrypted using PKI for the public key 2 (base64)
    └── ...
```

The `public_key_hash1` key value is the *SHA1* of the public key used for encryption.

Its content is the data encoded in *JSON*, then encrypted with the public key, and finally encoded in *base64*. The encryption is done using the *RSA* algorithm (PKI).

### EncryptedMash::Version1 (default)

This is the `EncryptedMash` version used by default. Uses public key cryptography (PKI) to encrypt a shared secret. Then this shared secret is used to encrypt the data.

* This implementation can be improved, is not optimized either for performance or for space.
* Every time the `EncryptedAttribute` is updated, all the shared secrets are regenerated.

#### EncryptedMash::Version1 Structure

If you try to read this encrypted attribute structure, you can see a *Mash* attribute with the following content:

```
EncryptedMash
├── chef_type: "encrypted_attribute" (string).
├── x_json_class: The used `EncryptedMash` version class name (string).
├── encrypted_data
│   ├── cipher: The used PKI algorithm, "aes-256-cbc" (string).
│   ├── data: PKI encrypted data (base64).
│   └── iv: Initialization vector (in base64).
├── encrypted_secret
│   ├── pub_key_hash1: The shared secrets encrypted for the public key 1 (base64).
│   ├── pub_key_hash2: The shared secrets encrypted for the public key 2 (base64).
│   └── ...
└── hmac
    ├── cipher: The used HMAC algorithm, currently ignored and always "sha256" (string).
    └── data: Hash-based message authentication code value (base64).
```

* `x_json_class` field is used, with the `x_` prefix, to be easily integrated with Chef in the future.

##### EncryptedMash[encrypted_data][data]

The data inside `encrypted_data` is symmetrically encrypted using the secret shared key. The data is converted to *JSON* before the encryption, then encrypted and finally encoded in *base64*. By default, the `"aes-256-cbc"` algorithm is used for encryption.

After decryption, the *JSON* has the following structure:

```
└── encrypted_data
    └── data (symmetrically encrypted JSON in base64)
        └── content: attribute content as a Mash.
```

* In the future, this structure may contain some metadata like default configuration values.

##### EncryptedMash[encrypted_secret][pub_key_hash1]

The `public_key_hash1` key value is the *SHA1* of the public key used for encryption.

Its content is the encrypted shared secrets in *base64*. The encryption is done using the *RSA* algorithm (PKI).

After decryption, you find the following structure in *JSON*:

```
└── encrypted_secret
    └── pub_key_hash1 (PKI encrypted JSON in base64)
        ├── data: The shared secret used to encrypt the data (base64).
        └── hmac: The shared secret used for the HMAC calculation (base64).
```

##### EncryptedMash[hmac][data]

The HMAC data is in *base64*. The hashing algorithm used is `"sha256"`.

The following data is used in a alphabetically sorted *JSON* to calculate the HMAC:

```
Data to calculate the HMAC from
├── cipher: The algorithm used for `encrypted_data` encryption ("aes-256-cbc").
├── data: The `encrypted_data` data content after the encryption (encrypt-then-mac).
└── iv: The initialization vector used to encrypt the encrypted_data.
```

* All the data required for decryption is included in the HMAC (except the secret key, of course): `cipher`, `data` and `iv`.
* The data used to calculate the HMAC is the encrypted data, not the clear text data (**Encrypt-then-MAC**).
* The secret used to calculate the HMAC is not the same as the secret used to encrypt the data.
* The secret used to calculate the HMAC is shared inside `encrypted_secret` field with the data secret.

### EncryptedMash::Version2

Uses public key cryptography (PKI) to encrypt a shared secret. Then this shared secret is used to encrypt the data using [GCM](http://en.wikipedia.org/wiki/Galois/Counter_Mode).

* This protocol version is based on the [Chef 12 Encrypted Data Bags Version 3 implementation](https://github.com/opscode/chef/pull/1591).
* To use it, the following **special requirements** must be met:
 * Ruby `>= 2`.
 * OpenSSL `>= 1.0.1`.
* This implementation can be improved, is not optimized either for performance or for space.
* Every time the `EncryptedAttribute` is updated, all the shared secrets are regenerated.

#### EncryptedMash::Version2 Structure

If you try to read this encrypted attribute structure, you can see a *Mash* attribute with the following content:

```
EncryptedMash
├── chef_type: "encrypted_attribute" (string).
├── x_json_class: The used `EncryptedMash` version class name (string).
├── encrypted_data
│   ├── cipher: The used PKI algorithm, "aes-256-gcm" (string).
│   ├── data: PKI encrypted data (base64).
│   ├── auth_tag: GCM authentication tag (base64).
│   └── iv: Initialization vector (in base64).
└── encrypted_secret
    ├── pub_key_hash1: The shared secret encrypted for the public key 1 (base64).
    ├── pub_key_hash2: The shared secret encrypted for the public key 2 (base64).
    └── ...
```

* `x_json_class` field is used, with the `x_` prefix, to be easily integrated with Chef in the future.

##### EncryptedMash[encrypted_data][data]

The data inside `encrypted_data` is symmetrically encrypted using the secret shared key. The data is converted to *JSON* before the encryption, then encrypted and finally encoded in *base64*. By default, the `"aes-256-gcm"` algorithm is used for encryption.

After decryption, the *JSON* has the following structure:

```
└── encrypted_data
    └── data (symmetrically encrypted JSON in base64)
        └── content: attribute content as a Mash.
```

* In the future, this structure may contain some metadata like default configuration values.

##### EncryptedMash[encrypted_secret][pub_key_hash1]

The `public_key_hash1` key value is the *SHA1* of the public key used for encryption.

Its content is the encrypted shared secret in *raw*. The encryption is done using the *RSA* algorithm (PKI).

After decryption, you find the shared secret in *raw* (in *Version1* this is a *JSON* in *base64*).
