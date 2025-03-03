# frozen_string_literal: true

require_relative "wat/version"

class Wat
  TYPE_ALIASES = { Int: :int, Bool: :bool, String: :string }

  CORE = {
    add: { fn: proc { |x, y| x + y }, type: [:fn, [:int, :int], :int] },
    sub: { fn: proc { |x, y| x - y }, type: [:fn, [:int, :int], :int] },
    mul: { fn: proc { |x, y| x * y }, type: [:fn, [:int, :int], :int] },
    eq:  { fn: proc { |x, y| x == y }, type: [:fn, [:int, :int], :bool] }
  }

  def initialize
    @env = CORE.transform_values { |v| v[:fn] }
    @type_env = CORE.transform_values { |v| v[:type] }
  end

  def eval(program)
    ast = parse(program)
    puts "AST: #{ast.inspect}"
    ast.each { |exp| type_check(exp) }
    ast.map { |exp| evaluate(exp) }.last
  end

  private

  def parse(str)
    tokens = []
    buffer = String.new  # Mutable string
    in_quotes = false
    str.chars.each do |c|
      if c == '"'
        if in_quotes
          buffer << c  # Closing quote
          tokens << buffer
          buffer = String.new  # Reset to new mutable string
        else
          buffer << c if buffer.empty?  # Opening quote
        end
        in_quotes = !in_quotes
      elsif in_quotes
        buffer << c
      elsif c =~ /[\[\]()]/  # Brackets
        tokens << buffer unless buffer.empty?
        tokens << c
        buffer = String.new
      elsif c =~ /\s/  # Whitespace
        tokens << buffer unless buffer.empty?
        buffer = String.new
      else
        buffer << c
      end
    end
    tokens << buffer unless buffer.empty?
    tokens.reject(&:empty?)
    puts "Tokens: #{tokens.inspect}"
    read_expressions(tokens)
  end

  def read_expressions(tokens, acc = [], depth = 0)
    raise "Syntax error: unclosed parenthesis" if tokens.empty? && depth > 0
    return acc if tokens.empty? && depth == 0
    token = tokens.shift
    # binding.pry  # Breakpoint 1: Check token parsing
    case token
    when '('
      exp = read_expressions(tokens, [], depth + 1)
      acc << exp
      read_expressions(tokens, acc, depth)
    when '['
      param = []
      while tokens[0] != ']'
        sub_token = tokens.shift
        case sub_token
        when ':'
          type = tokens.shift.to_sym
          param << sub_token << type
        else
          param << (integer?(sub_token) ? sub_token.to_i : sub_token.to_sym)
        end
      end
      raise "Syntax error: expected ]" unless tokens[0] == ']'
      tokens.shift
      if param.length == 3 && param[1] == ':'  # [x : Int]
        acc << [param[0], param[2]]
      else
        raise "Syntax error: invalid param format, expected [name : Type]"
      end
      read_expressions(tokens, acc, depth)
    when ')'
      raise "Syntax error: unexpected closing parenthesis" if depth == 0
      acc
    when ']'
      raise "Syntax error: unexpected closing bracket" if depth == 0
      acc
    when ':'
      if depth > 0 && acc[0] == :defn && tokens[0] =~ /^[A-Z]/
        acc << tokens.shift.to_sym
      else
        raise "Syntax error: stray colon"
      end
      read_expressions(tokens, acc, depth)
    else
      # Handle quoted strings as string values
      if token.start_with?('"') && token.end_with?('"')
        acc << token[1..-2]  # Strip quotes, keep as string
      else
        acc << (integer?(token) ? token.to_i : token.to_sym)
      end
      read_expressions(tokens, acc, depth)
    end
  end

  def integer?(str)
    str =~ /^\d+$/
  end

  def type_check(exp, env = @type_env, locals = {})
    puts "Type checking: #{exp.inspect}, Locals: #{locals.inspect}"
    return :int if exp.is_a?(Integer)
    return :string if exp.is_a?(String)  # String literals
    # binding.pry  # Breakpoint 2: Check type resolution
    if exp.is_a?(Symbol)
      type = locals[exp] || env[exp]
      return TYPE_ALIASES[type] || type if type
      raise "Unknown variable or function: #{exp}"
    end
    case exp[0]
    when :defn
      name = exp[1]
      body_idx = exp.index { |x| x.is_a?(Array) && x.length != 2 } || exp.length - 1
      param_end = exp[2...(body_idx - 1)].select { |x| x.is_a?(Array) && x.length == 2 }.length + 2
      params = exp[2...param_end]
      ret_type = TYPE_ALIASES[exp[param_end]] || exp[param_end]  # Normalize :Int to :int
      body = exp[body_idx]
      param_types = params.map { |p| TYPE_ALIASES[p[1]] || p[1] }  # Normalize :Int to :int
      fn_type = [:fn, param_types, TYPE_ALIASES[ret_type] || ret_type]
      env[name] = fn_type
      locals = params.map { |p| [p[0], TYPE_ALIASES[p[1]] || p[1]] }.to_h  # {x: :int, y: :int}
      body_type = type_check(body, env, locals)
      raise "Type error: expected :#{ret_type}, got :#{body_type} in #{name}" unless body_type == ret_type
      :nil
    else
      fn_name, *args = exp
      fn_type = env[fn_name] || raise("Unknown function: #{fn_name}")
      return_type = fn_type[-1]
      arg_types = fn_type[1]
      args.each_with_index do |arg, i|
        arg_type = type_check(arg, env, locals)
        expected = arg_types[i]
        raise "Type error: expected #{expected}, got #{arg_type} in #{fn_name}" unless arg_type == expected
      end
      return_type
    end
  end

  def evaluate(exp, env = @env)
    puts "Evaluating: #{exp.inspect}, Env: #{env.inspect}"
    return exp if exp.is_a?(Integer)
    return exp if exp.is_a?(String)  # Return string literals
    # binding.pry  # Breakpoint 3: Check value resolution
    if exp.is_a?(Symbol)
      return env[exp] if env.key?(exp) && !env[exp].is_a?(Proc)
      return env[exp].call if env.key?(exp)
      raise "Unknown variable or function: #{exp}"
    end
    case exp[0]
    when :defn
      name = exp[1]
      body_idx = exp.index { |x| x.is_a?(Array) && x.length != 2 } || exp.length - 1
      param_end = exp[2...(body_idx - 1)].select { |x| x.is_a?(Array) && x.length == 2 }.length + 2
      params = exp[2...param_end]
      body = exp[body_idx]
      puts "Defn: name=#{name}, params=#{params.inspect}, body=#{body.inspect}"
      @env[name] = proc { |*args|
        new_locals = params.map { |p| p[0] }.zip(args).to_h  # {x: 2, y: 3}
        puts "Calling #{name} with args=#{args.inspect}, new_locals=#{new_locals.inspect}"
        evaluate(body, env.merge(new_locals))
      }
      nil
    else
      fn_name, *args = exp
      fn = env[fn_name] || raise("Unknown function: #{fn_name}")
      expected_arity = fn.arity
      actual_arity = args.size
      raise "Arity error: #{fn_name} expects #{expected_arity} args, got #{actual_arity}" unless expected_arity == actual_arity || expected_arity < 0
      fn.call(*args.map { |a| evaluate(a, env) })
    end
  end
end
