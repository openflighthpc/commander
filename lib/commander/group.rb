module Commander
  class Group

    attr_accessor :name, :summary, :description, :syntax

    def initialize(name)
      @name = name.to_s
    end

    def commands
      @commands ||= {}
    end

    def command(name)
      name = name.to_s
      (commands[name] ||= Command.new(name, self)).tap do |cmd|
        yield cmd if block_given?
      end
    end
  end
end
