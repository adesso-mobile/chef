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

require 'chef/mixin/checksum'
require 'chef/mixin/backupable_file_resource'
require 'chef/mixin/diffable_file_resource'

class Chef
  class Provider
    class FileStrategy
      class ContentStrategy
        include Chef::Mixin::Checksum
        include Chef::Mixin::DiffableFileResource
        include Chef::Mixin::BackupableFileResource

        attr_accessor :run_context

        def initialize(provider, content_object, new_resource, current_resource, run_context)
          @provider = provider
          @content_object = content_object
          @new_resource = new_resource
          @current_resource = current_resource
          @run_context = run_context
        end

        def do_create_file
          unless ::File.exists?(@new_resource.path)
            description = "create new file #{@new_resource.path}"
            @provider.converge_by(description) do
              FileUtils.touch(@new_resource.path)
              Chef::Log.info("#{@new_resource} created file #{@new_resource.path}")
            end
          end
        end

        def tempfile_to_destfile
          if tempfile.path && ::File.exists?(tempfile.path)
            backup @new_resource.path if ::File.exists?(@new_resource.path)
            FileUtils.cp(tempfile.path, @new_resource.path)
          end
        end

        def do_contents_changes
          if contents_changed?
            description = [ "update content in file #{@new_resource.path} from #{short_cksum(@current_resource.checksum)} to #{short_cksum(checksum)}" ]
            description << diff(tempfile.path)
            @provider.converge_by(description) do
              tempfile_to_destfile
              Chef::Log.info("#{@new_resource} updated file contents #{@new_resource.path}")
            end
          end
          cleanup
        end

        def contents_changed?
          !checksum.nil? && checksum != @current_resource.checksum
        end

        def tempfile
          @content_object.tempfile
        end

        def checksum
          return nil if tempfile.nil? || tempfile.path.nil?
          Chef::Digester.checksum_for_file(tempfile.path)
        end

        private

        def cleanup
          tempfile.unlink unless tempfile.nil?
        end

        def whyrun_mode?
          Chef::Config[:why_run]
        end

        def short_cksum(checksum)
          return "none" if checksum.nil?
          checksum.slice(0,6)
        end
      end
    end
  end
end

