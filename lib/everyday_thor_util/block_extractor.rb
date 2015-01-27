module EverydayThorUtil
  class ParseState
    attr_accessor :depth, :last_depth, :state, :last_state, :char, :last_char

    STRING_TYPE_MAP = {
        '"' => :double,
        "'" => :single,
        '`' => :backtick,
        '/' => :regex
    }

    STRING_TYPES_SUPPORTING_SUBSTITUTIONS = [:double, :backtick, :regex]

    def get_string_type
      STRING_TYPE_MAP[@char] || :none
    end

    def string_type_subs?
      STRING_TYPES_SUPPORTING_SUBSTITUTIONS.include?(self.string_type)
    end

    def parent_string_type_subs?
      STRING_TYPES_SUPPORTING_SUBSTITUTIONS.include?(self.parent_string_type)
    end

    def initialize
      @depth             = 0
      @last_depth        = 0
      @state             = :before_start
      @last_state        = @state
      @char              = nil
      @last_char         = @char
      @string_type_stack = []
      @depth_stack       = []
    end

    def state_is_and_was(state)
      @state == state && @last_state == state
    end

    def string_type
      @string_type_stack.first || :none
    end

    def parent_string_type
      @string_type_stack[1] || :none
    end

    def push_string_type(string_type)
      @string_type_stack.unshift(string_type)
    end

    def pop_string_type
      @string_type_stack.shift
    end

    def push_depth
      @depth_stack.unshift(@depth)
    end

    def pop_depth
      @depth_stack.shift
    end

    def peek_depth
      @depth_stack.first
    end

    def step
      @last_depth = @depth
      @last_state = @state
      @last_char  = @char
    end
  end

  class BlockExtractor
    class << self
      def extract_block(name, indentation = 0, &block)
        extract_lambda(name, block, indentation)
      end

      def extract_lambda(name, block, indentation = 0)
        filename, line_number = block.source_location
        file_data             = IO.readlines(filename)
        file_data             = file_data[(line_number-1)..-1]
        output_data           = []
        param_string          = ''
        ps                    = ParseState.new
        file_data.each { |l|
          line    = l.chomp
          outline = ''
          line.each_char { |c|
            ps.char     = c
            string_type = ps.get_string_type
            if string_type != :none
              if ps.string_type == :none
                ps.push_string_type string_type
              elsif ps.string_type == string_type && ps.last_char != '\\'
                ps.pop_string_type
              end
            elsif c == '{' && ps.last_char == '#' && ps.string_type_subs?
              ps.push_string_type :none
              ps.push_depth
            elsif c == '}' && ps.string_type == :none && ps.peek_depth == ps.depth && ps.parent_string_type_subs?
              ps.pop_string_type
              ps.pop_depth
            elsif ps.string_type == :none
              if c == '|'
                if ps.state == :before_start
                  ps.state = :in_params
                elsif ps.state == :in_params
                  ps.state = :in_body
                end
              elsif c == '>'
                if ps.last_char == '-' && ps.state == :before_start && block.lambda?
                  ps.state = :starting_lambda
                end
              elsif c == '('
                if ps.state == :starting_lambda
                  ps.state = :in_params
                end
              elsif c == ')'
                if ps.state == :in_params
                  ps.state = :lambda_ready
                end
              elsif c == '{'
                if ps.state != :in_params
                  ps.depth += 1
                end
              elsif c == '}'
                if ps.state != :in_params
                  ps.depth -= 1
                  ps.state = :after_end if ps.depth == 0
                end
              end
            end
            if ps.state == :after_end
              break
            end
            if (ps.state == :lambda_ready || ps.state == :starting_lambda) && ps.depth == 1
              ps.state = :in_body
            end
            if ps.state == :before_start && ps.depth == 1 && (c =~ /[\s\{]/).nil?
              ps.state      = :in_body
              ps.last_state = :in_body
            end
            if ps.state_is_and_was :in_params
              param_string << c
            elsif ps.state_is_and_was :in_body
              outline << c
            end
            ps.step
          }
          output_data << outline
          if ps.state == :after_end
            break
          end
        }
        output_data.delete_at(0) if output_data[0].strip.empty?
        output_data.delete_at(-1) if output_data[-1].strip.empty?
        contents_indentation = output_data[0].length - output_data[0].lstrip.length
        output_data          = output_data.map { |ol|
          ol2 = ol.lstrip
          ld  = ol.length - ol2.length - contents_indentation
          ol2 = "#{' ' * ld}#{ol2}" if ld > 0
          "#{' ' * (indentation + 2)}#{ol2}"
        }
        output_data.unshift("#{' ' * indentation}def #{name.to_s}#{param_string.empty? ? '' : "(#{param_string})"}")
        output_data << "#{' ' * indentation}end"
        output_data
      end
    end
  end
end