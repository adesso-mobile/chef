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

#require 'chef/provider/file_strategy/content_strategy'

class Chef
  class Provider
    class FileStrategy
      class ContentFromResource
        def initialize(new_resource, current_resource, run_context)
          @new_resource = new_resource
          @current_resource = current_resource
          @run_context = run_context
        end

        def tempfile
          @tempfile ||= begin
                          if @new_resource.content
                            tempfile = Tempfile.open(::File.basename(@new_resource.name))
                            tempfile.write(@new_resource.content)
                            tempfile.close
                            tempfile
                          else
                            nil
                          end
                        end
        end
      end
    end
  end
end
