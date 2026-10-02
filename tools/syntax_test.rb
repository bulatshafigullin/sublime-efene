# Runs Sublime Text syntax test files without Sublime Text, implementing the
# parts of the .sublime-syntax format Efene.sublime-syntax uses (match, scope,
# captures, push, pop, include, meta_scope, variables) and the assertion syntax
# of syntax_test_* files (^ and <- with scope selectors and - exclusions).
#
#   ruby tools/syntax_test.rb Efene.sublime-syntax syntax_test_efene.fn
#
# Ruby's regex engine (Onigmo) is the one Sublime Text 3 uses (Oniguruma)
# for its syntaxes, so the patterns are checked too.
require "yaml"

class Syntax
  def initialize(path)
    data = YAML.safe_load(File.read(path))
    @scope = data["scope"]
    vars = data["variables"] || {}
    @vars = {}
    vars.each_key { |k| @vars[k] = expand(vars[k], vars) }
    @contexts = data["contexts"]
    @compiled = {}
  end

  def expand(text, vars = @vars)
    text.gsub(/\{\{(\w+)\}\}/) { expand(vars.fetch($1), vars) }
  end

  # patterns of a context with the includes flattened, regexes compiled
  def patterns(name_or_list)
    return @compiled[name_or_list] if name_or_list.is_a?(String) && @compiled[name_or_list]
    list = name_or_list.is_a?(String) ? @contexts.fetch(name_or_list) : name_or_list
    result = []
    list.each do |rule|
      if rule["include"]
        result.concat(patterns(rule["include"]))
      elsif rule["match"]
        result << rule.merge("regex" => Regexp.new(expand(rule["match"])))
      end
    end
    @compiled[name_or_list] = result if name_or_list.is_a?(String)
    result
  end

  def meta_scope(list) = (list.find { |r| r["meta_scope"] } || {})["meta_scope"]

  def context_list(name_or_list)
    name_or_list.is_a?(String) ? @contexts.fetch(name_or_list) : name_or_list
  end

  # list of lines, each a list of per character scope arrays
  def tokenize(text)
    stack = ["main"]
    text.lines.map do |raw|
      line = raw.end_with?("\n") ? raw : raw + "\n"
      scopes = Array.new(line.length)
      pos = 0
      while pos < line.length
        best = nil
        patterns(stack.last).each do |rule|
          m = rule["regex"].match(line, pos)
          next unless m
          best = [m, rule] if best.nil? || m.begin(0) < best[0].begin(0)
        end
        base = stack_scopes(stack)
        unless best
          (pos...line.length).each { |i| scopes[i] = base }
          break
        end
        m, rule = best
        (pos...m.begin(0)).each { |i| scopes[i] = base }
        match_base = base
        if rule["push"]
          stack = stack + [rule["push"]]
          match_base = stack_scopes(stack)
        end
        whole = split(rule["scope"])
        (m.begin(0)...m.end(0)).each { |i| scopes[i] = match_base + whole }
        (rule["captures"] || {}).each do |n, sc|
          next unless m.begin(n.to_i)
          (m.begin(n.to_i)...m.end(n.to_i)).each { |i| scopes[i] = match_base + whole + split(sc) }
        end
        stack = stack[0...-1] if rule["pop"]
        pos = m.end(0) > pos ? m.end(0) : pos + 1
      end
      scopes.map { |s| s || stack_scopes(stack) }
    end
  end

  def stack_scopes(stack)
    [@scope] + stack.flat_map { |c| split(meta_scope(context_list(c))) }
  end

  def split(s) = s ? s.split : []
end

# "a.b c - d" against a scope list
def selector_matches?(selector, scopes)
  positive, *negatives = (" " + selector).split(" - ")
  matches = lambda do |sel|
    i = 0
    sel.split.all? do |part|
      found = (i...scopes.length).find { |j| scopes[j] == part || scopes[j].start_with?(part + ".") }
      found && (i = found + 1)
    end
  end
  matches.(positive) && negatives.none? { |n| matches.(n) }
end

if __FILE__ == $PROGRAM_NAME
  syntax_path, test_path = ARGV
  syntax = Syntax.new(syntax_path)
  lines = File.read(test_path).lines
  header = lines.first[/\A(\S+)\s+SYNTAX TEST/, 1] or abort "no SYNTAX TEST header"
  tokens = syntax.tokenize(lines.join)
  failures = 0
  checks = 0
  code_line = nil
  lines.each_with_index do |line, n|
    next if n == 0
    unless line.start_with?(header)
      code_line = n
      next
    end
    body = line[header.length..]
    if (m = body.match(/\A\s*<-\s*(.+)/))
      columns = [0]
      selector = m[1].strip
    elsif (m = body.match(/\A(\s*)(\^+)\s*(.+)/))
      start = header.length + m[1].length
      columns = (start...start + m[2].length).to_a
      selector = m[3].strip
    else
      next
    end
    columns.each do |col|
      checks += 1
      scopes = tokens[code_line][col] || []
      next if selector_matches?(selector, scopes)
      failures += 1
      puts "#{test_path}:#{n + 1}: col #{col} of line #{code_line + 1} " \
           "(#{lines[code_line][col].inspect}) expected #{selector}, got: #{scopes.join(' ')}"
    end
  end
  puts "#{checks} assertions, #{failures} failures"
  exit(failures.zero? ? 0 : 1)
end
