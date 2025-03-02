# frozen_string_literal: true

require_relative "wat/version"

class Wat
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
    ast.each { |exp| type_check(exp) }  # Multi-form
    ast.map { |exp| evaluate(exp) }.last
  end

  private

  def parse(str)
    tokens = str.gsub(/[()]/, ' \0 ').split.map(&:strip)
    puts "Tokens: #{tokens.inspect}"  # Debug
    read_expressions(tokens)
  end

  def read_expressions(tokens, acc = [], depth = 0)
    raise "Syntax error: unclosed parenthesis" if tokens.empty? && depth > 0
    return acc if tokens.empty? && depth == 0
    token = tokens.shift
    case token
    when '('
      exp = read_expressions(tokens, [], depth + 1)
      acc << exp
      read_expressions(tokens, acc, depth)
    when ')'
      raise "Syntax error: unexpected closing parenthesis" if depth == 0
      acc
    else
      acc << (integer?(token) ? token.to_i : token.to_sym)
      read_expressions(tokens, acc, depth)
    end
  end

  def integer?(str)
    str =~ /^\d+$/
  end

  def type_check(exp, env = @type_env, locals = {})
    puts "Type checking: #{exp.inspect}, Locals: #{locals.inspect}"
    return :int if exp.is_a?(Integer)
    if exp.is_a?(Symbol)
      return locals[exp] if locals.key?(exp)
      return env[exp] if env.key?(exp)
      raise "Unknown variable or function: #{exp}"
    end
    case exp[0]
    when :defn
      name = exp[1]
      body_idx = exp.index { |x| x.is_a?(Array) }  # Find body (first sub-expression)
      params = exp[2...body_idx]  # All args before body
      body = exp[body_idx]
      param_types = params.map { :int }  # Untyped: assume Int
      fn_type = [:fn, param_types, type_check(body, env, params.map { |p| [p, :int] }.to_h)]
      env[name] = fn_type
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
    if exp.is_a?(Symbol)
      return env[exp] if env.key?(exp) && !env[exp].is_a?(Proc)
      return env[exp].call if env.key?(exp)
      raise "Unknown variable or function: #{exp}"
    end
    case exp[0]
    when :defn
      name = exp[1]
      body_idx = exp.index { |x| x.is_a?(Array) }  # Find body
      params = exp[2...body_idx]  # Split params correctly
      body = exp[body_idx]
      puts "Defn: name=#{name}, params=#{params.inspect}, body=#{body.inspect}"  # Debug
      @env[name] = proc { |*args|
        new_locals = params.zip(args).to_h  # { x: 2, y: 3 }
        puts "Calling #{name} with args=#{args.inspect}, new_locals=#{new_locals.inspect}"  # Debug
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
