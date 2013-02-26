#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Lamont Granquist (<lamont@opscode.com>)
# Copyright:: Copyright (c) 2008-2013 Opscode, Inc.
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

require 'chef/config'
require 'chef/log'
require 'chef/resource/file'
require 'chef/provider'
require 'etc'
require 'fileutils'
require 'chef/scan_access_control'
require 'chef/mixin/checksum'
require 'chef/mixin/backupable_file_resource'
require 'chef/provider/file_strategy/content_strategy'
require 'chef/provider/file_strategies'

class Chef
  class Provider
    class File < Chef::Provider
      include Chef::Mixin::EnforceOwnershipAndPermissions
      include Chef::Mixin::Checksum
      include Chef::Mixin::BackupableFileResource

      attr_accessor :content_strategy

      def initialize(new_resource, run_context)
        @content_class ||= Chef::Provider::FileStrategy::ContentFromResource
        super
      end

      def whyrun_supported?
        true
      end

      def content_object
        @content_object ||= @content_class.new(@new_resource, @current_resource, @run_context)
      end

      def deployer
        @deployer ||= Chef::Provider::FileStrategy::DeployMv.new
      end

      def content_strategy
        @content_strategy ||= Chef::Provider::FileStrategy::ContentStrategy.new(self, content_object,  deployer, new_resource, current_resource, run_context)
      end

      def load_current_resource
        # Let children resources override constructing the @current_resource
        @current_resource ||= Chef::Resource::File.new(@new_resource.name)
        @new_resource.path.gsub!(/\\/, "/") # for Windows
        @current_resource.path(@new_resource.path)
        load_resource_attributes_from_file(@current_resource)
        @current_resource
      end

      def define_resource_requirements
        # Make sure the parent directory exists, otherwise fail.  For why-run assume it would have been created.
        requirements.assert(:create, :create_if_missing, :touch) do |a|
          parent_directory = ::File.dirname(@new_resource.path)
          a.assertion { ::File.directory?(parent_directory) }
          a.failure_message(Chef::Exceptions::EnclosingDirectoryDoesNotExist, "Parent directory #{parent_directory} does not exist.")
          a.whyrun("Assuming directory #{parent_directory} would have been created")
        end

        # Make sure the file is deletable if it exists, otherwise fail.
        if ::File.exists?(@new_resource.path)
          requirements.assert(:delete) do |a|
            a.assertion { ::File.writable?(@new_resource.path) }
            a.failure_message(Chef::Exceptions::InsufficientPermissions,"File #{@new_resource.path} exists but is not writable so it cannot be deleted")
          end
        end
      end

      # if you are using a tempfile before creating, you must
      # override the default with the tempfile, since the
      # file at @new_resource.path will not be updated on converge
      def load_resource_attributes_from_file(resource)
        if resource.respond_to?(:checksum)
          if ::File.exists?(resource.path) && !::File.directory?(resource.path)
            if @action != :create_if_missing # XXX: don't we break current_resource semantics by skipping this?
              resource.checksum(checksum(resource.path))
            end
          end
        end

        if Chef::Platform.windows?
          # TODO: To work around CHEF-3554, add support for Windows
          # equivalent, or implicit resource reporting won't work for
          # Windows.
          return
        end

        acl_scanner = ScanAccessControl.new(@new_resource, resource)
        acl_scanner.set_all!
      end

      def do_acl_changes
        if access_controls.requires_changes?
          converge_by(access_controls.describe_changes) do
            access_controls.set_all
          end
        end
      end

      def action_create
        content_strategy.do_create_file
        content_strategy.do_contents_changes
        do_acl_changes
        load_resource_attributes_from_file(@new_resource)
      end

      def action_create_if_missing
        if ::File.exists?(@new_resource.path)
          Chef::Log.debug("#{@new_resource} exists at #{@new_resource.path} taking no action.")
        else
          action_create
        end
      end

      def action_delete
        if ::File.exists?(@new_resource.path)
          converge_by("delete file #{@new_resource.path}") do
            backup unless ::File.symlink?(@new_resource.path)
            ::File.delete(@new_resource.path)
            Chef::Log.info("#{@new_resource} deleted file at #{@new_resource.path}")
          end
        end
      end

      def action_touch
        action_create
        converge_by("update utime on file #{@new_resource.path}") do
          time = Time.now
          ::File.utime(time, time, @new_resource.path)
          Chef::Log.info("#{@new_resource} updated atime and mtime to #{time}")
        end
      end

    end
  end
end

