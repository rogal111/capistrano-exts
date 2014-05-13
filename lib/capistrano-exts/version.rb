module Capistrano
  module Extensions
    module Version #:nodoc:
      MAJOR = 2
      MINOR = 0
      TINY = 1

      ARRAY  = [MAJOR, MINOR, TINY]
      STRING = ARRAY.join(".")
    end
  end
end
