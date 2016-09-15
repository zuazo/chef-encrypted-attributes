# encoding: UTF-8
#
# Author:: Xabier de Zuazo (<xabier@zuazo.org>)
# Copyright:: Copyright (c) 2014 Onddo Labs, SL.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class Chef
  class EncryptedAttribute
    # Exception raised when some requirements to use the encrypted attributes
    # are not met.
    class RequirementsFailure < StandardError; end
    # Exception raised when the encrypted attribute format is unknown.
    class UnsupportedEncryptedAttributeFormat < StandardError; end
    # Exception raised when the encrypted attribute format is wrong.
    class UnacceptableEncryptedAttributeFormat < StandardError; end
    # Exception raised when there are decryption errors.
    class DecryptionFailure < StandardError; end
    # Exception raised when there are encryption errors.
    class EncryptionFailure < StandardError; end
    # Exception raised when there errors generating the HMAC.
    class MessageAuthenticationFailure < StandardError; end
    # Exception raised when the public key is wrong.
    class InvalidPublicKey < StandardError; end
    # Exception raised when the key is wrong.
    class InvalidKey < StandardError; end

    # Exception raised when you don't have enough privileges in the Chef Server
    # to do what you intend. Usually happens when you try to read Client or Node
    # keys without being admin.
    class InsufficientPrivileges < StandardError; end
    # Exception raised when the user does not exist.
    class UserNotFound < StandardError; end
    # Exception raised when the client does not exist.
    class ClientNotFound < StandardError; end

    # Exception raised for search errors.
    class SearchFailure < StandardError; end
    # Exception raised for search fatal errors.
    class SearchFatalError < StandardError; end
    # Exception raised when search keys are wrong.
    class InvalidSearchKeys < StandardError; end
  end
end
