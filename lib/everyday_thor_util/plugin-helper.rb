require 'thor-fix'
require 'everyday-plugins'
include EverydayPlugins
require 'thor'

class Thor
  class << self
    def create_method(name, &block)
      self.send(:define_method, name, &block)
    end
  end
end

module EverydayThorUtil
  class SubCommandTypes
    extend PluginType
    extend TypeHelper

    class << self
      def def_types(command_array_symbol, flag_symbol, command_symbol)
        register_variable command_array_symbol, []

        register_type(flag_symbol) { |list, parent_class, parent, has_children|
          filtered_list = list.select { |v| v[:options][:parent] == parent }
          filtered_list.each { |v|
            opts            = {}
            name            = v[:options][:name].to_sym
            opts[:desc]     = v[:options][:desc] if v[:options][:desc]
            opts[:banner]   = v[:options][:banner] if v[:options][:banner]
            opts[:required] = v[:options][:required] if v[:options][:required] && !v[:options][:default]
            opts[:default]  = v[:options][:default] if v[:options][:default]
            opts[:type]     = v[:options][:type] if v[:options][:type]
            opts[:aliases]  = v[:options][:aliases] if v[:options][:aliases]
            has_children ? parent_class.class_option(name, opts) : parent_class.option(name, opts)
          }
        }

        register_type(command_symbol) { |list, parent_class, parent|
          Plugins.get flag_symbol, parent_class, nil, true unless parent
          filtered_list = list.select { |v| v[:options][:parent] == parent || nil }
          filtered_list.each { |v|
            id         = v[:options][:id]
            short_desc = v[:options][:short_desc]
            desc       = v[:options][:desc]
            long_desc  = v[:options][:long_desc]
            name       = v[:options][:name]
            if id && name
              has_children = list.any? { |v2| v2[:options][:parent] == id }
              if has_children
                command_ids = Plugins.get_var command_array_symbol
                unless command_ids.include?(id)
                  command_ids << id
                  Plugins.set_var command_array_symbol, command_ids
                  command_class = Class.new(Thor)
                  command_class.namespace name
                  Plugins.get flag_symbol, command_class, id, true
                  Plugins.get command_symbol, command_class, id
                  Plugins.get flag_symbol, parent_class, id, false
                  parent_class.desc short_desc, desc if short_desc && desc
                  parent_class.long_desc long_desc if long_desc
                  parent_class.subcommand name, command_class
                end
              elsif v[:block]
                Plugins.get flag_symbol, parent_class, id, false
                parent_class.desc short_desc, desc if short_desc && desc
                parent_class.long_desc long_desc if long_desc
                parent_class.create_method(name.to_sym, &v[:block])
              end
            end
          }
        }
      end
    end
  end
end
