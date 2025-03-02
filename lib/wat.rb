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
    @env = CORE.transform_values { |v| v[:fn] }  # Runtime env: procs only
    @type_env = CORE.transform_values { |v| v[:type] }  # Type env: signatures
  end

  def eval(program)
    ast = parse(program)
    type_check(ast[0])  # Check types before eval
    evaluate(ast[0])
  end

  private

  def parse(str)
    tokens = str.gsub(/[()]/, ' \0 ').split.map(&:strip)
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

  def type_check(exp, env = @type_env)
    return :int if exp.is_a?(Integer)
    return env[exp] if env.key?(exp)  # CORE function signature
    fn_name, *args = exp
    fn_type = env[fn_name] || raise("Unknown function: #{fn_name}")
    return_type = fn_type[-1]
    arg_types = fn_type[1]
    args.each_with_index do |arg, i|
      arg_type = type_check(arg, env)
      expected = arg_types[i]
      raise "Type error: expected #{expected}, got #{arg_type} in #{fn_name}" unless arg_type == expected
    end
    return_type
  end

  def evaluate(exp)
    return exp if exp.is_a?(Integer)
    return @env[exp].call if @env.key?(exp)
    fn_name, *args = exp
    fn = @env[fn_name] || raise("Unknown function: #{fn_name}")
    expected_arity = fn.arity
    actual_arity = args.size
    raise "Arity error: #{fn_name} expects #{expected_arity} args, got #{actual_arity}" unless expected_arity == actual_arity
    fn.call(*args.map { |a| evaluate(a) })
  end

  def evaluate(exp)
    return exp if exp.is_a?(Integer)
    return @env[exp].call if @env.key?(exp)
    fn_name, *args = exp
    fn = @env[fn_name] || raise("Unknown function: #{fn_name}")
    expected_arity = fn.arity
    actual_arity = args.size
    raise "Arity error: #{fn_name} expects #{expected_arity} args, got #{actual_arity}" unless expected_arity == actual_arity
    fn.call(*args.map { |a| evaluate(a) })
  end
end
