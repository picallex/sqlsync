# @author (2021) Jovany Leandro G.C <jovany@picallex.com>

class Sqlsync::Driver::Postgres < Sqlsync::Driver::CrystalDB
  class Quoter < Sqlsync::Quoter
  end

  def quoter
    Quoter.new
  end
end
