# @author (2021) Jovany Leandro G.C <jovany@picallex.com>

require "./sqlsync/table"
require "./sqlsync/diff"
require "./sqlsync/drivers"
require "./sqlsync/domain"
require "./sqlsync/value"

module Sqlsync
  VERSION = "0.1.0"

  def self.diff(source : Data, dest : Data) : Diff
    Diff.new(source, dest)
  end
end
