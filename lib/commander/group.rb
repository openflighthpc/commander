module Commander
  class Group

    attr_accessor :name, :description

    def initialize(name)
      @name = name.to_s
      @description = ""
    end

    def commands
      @commands ||= {}
    end

    def command(name)
      name = name.to_s
      (commands[name] ||= Command.new(name)).tap do |cmd|
        yield cmd if block_given?
      end
    end
  end
end
