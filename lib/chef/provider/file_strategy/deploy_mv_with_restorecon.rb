#
# Author:: Lamont Granquist (<lamont@opscode.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.
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

require 'chef/mixin/shell_out'
require 'chef/provider/file_strategy/deploy_mv'

#
# PURPOSE: this strategy is for servers running selinux to deploy using mv (atomically),
#          obey default umasks, and get selinux contexts restored.
#

class Chef
  class Provider
    class FileStrategy
      class DeployMvWithRestorecon < DeployMv
        include Chef::Mixin::ShellOut

        def deploy(src, dst)
          super
          shell_out!("/sbin/restorecon -R #{dst}")  # FIXME: config var for restorecon command to use
        end
      end
    end
  end
end
