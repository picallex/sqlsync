# @author (2021) Jovany Leandro G.C <jovany@picallex.com>
require "io/memory"

module Sqlsync::Value
  def self.eval(val : String)
    if val == "{sqlsync:hostname}"
      return System.hostname
    end

    if m = val.match(/{exec:(.*?)}/)
      cmd = m[1]
      io = IO::Memory.new
      p = Process.run(cmd, shell: true, output: io)
      if !p.normal_exit?
        STDERR.puts "fails to execute command #{cmd}"
        exit(1)
      else
        return io.to_s.chomp
      end
    end

    if m = val.match(/{env:(.*?)}/)
      env_name = m[1]
      return ENV[env_name]
    end
    return val
  end
end
