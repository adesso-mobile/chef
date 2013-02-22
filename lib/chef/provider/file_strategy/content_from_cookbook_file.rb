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

require 'chef/provider/file_strategy/content_strategy'

class Chef
  class Provider
    class FileStrategy
      class ContentFromCookbookFile < ContentStrategy
        def tempfile
          @tempfile ||= begin
                          cookbook = run_context.cookbook_collection[resource_cookbook]
                          file_cache_location = cookbook.preferred_filename_on_disk_location(run_context.node, :files, @new_resource.source, @new_resource.path)
                          if file_cache_location.nil?
                            nil
                          else
                            @tempfile = Tempfile.open(::File.basename(@new_resource.name))
                            @tempfile.close
                            Chef::Log.debug("#{@new_resource} staging #{file_cache_location} to #{@tempfile.path}")
                            FileUtils.cp(file_cache_location, @tempfile.path)
                            @tempfile
                          end
                        end
        end

        private

        def resource_cookbook
          @new_resource.cookbook || @new_resource.cookbook_name
        end
      end
    end
  end
end
