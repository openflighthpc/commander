module Commander
  class Group

    attr_accessor :name, :description

    def initialize(name, group: nil)
      @name = name.to_s
      @description = ""
    end
  end
end
