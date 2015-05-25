module Synced
  module Strategies
    class Check
      class Result
        def to_s
%Q{
#{line "synced_class", model_class}
#{line "options", options}
#{line "changed count", changed.size}
#{line "additional count", additional.size}
#{line "missing count", missing.size}
#{line "changed", changed}
#{line "additional", additional}
#{line "missing", missing}
}
        end

        private

        def line(label, value)
          "#{label}:".ljust(18) + "#{value}"
        end
      end
    end
  end
end
