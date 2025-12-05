#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "time"
require "fileutils"

module Todo
  VERSION = "0.1.0"

  class Item
    attr_reader :id, :title, :created_at
    attr_accessor :completed_at, :priority, :tags

    def initialize(id, title, priority: :normal, tags: [])
      @id = id
      @title = title
      @priority = priority
      @tags = tags
      @created_at = Time.now
      @completed_at = nil
    end

    def complete!
      @completed_at = Time.now
    end

    def uncomplete!
      @completed_at = nil
    end

    def completed?
      !@completed_at.nil?
    end

    def to_h
      {
        id: @id,
        title: @title,
        priority: @priority.to_s,
        tags: @tags,
        created_at: @created_at.iso8601,
        completed_at: @completed_at&.iso8601
      }
    end

    def self.from_h(hash)
      item = new(
        hash["id"],
        hash["title"],
        priority: hash["priority"]&.to_sym || :normal,
        tags: hash["tags"] || []
      )
      item.instance_variable_set(:@created_at, Time.parse(hash["created_at"]))
      if completed = hash["completed_at"]
        item.instance_variable_set(:@completed_at, Time.parse(completed))
      end
      item
    end
  end

  class List
    include Enumerable

    def initialize
      @items = {}
      @next_id = 1
    end

    def add(title, priority: :normal, tags: [])
      item = Item.new(@next_id, title, priority: priority, tags: tags)
      @items[@next_id] = item
      @next_id += 1
      item
    end

    def find(id)
      @items[id]
    end

    def delete(id)
      @items.delete(id)
    end

    def each(&block)
      return enum_for(:each) unless block
      @items.values.each(&block)
    end

    def pending
      select { |item| !item.completed? }
    end

    def completed
      select { |item| item.completed? }
    end

    def by_priority(priority)
      select { |item| item.priority == priority }
    end

    def by_tag(tag)
      select { |item| item.tags.include?(tag) }
    end

    def search(query)
      pattern = Regexp.new(query, Regexp::IGNORECASE)
      select { |item| item.title.match?(pattern) }
    end

    def size
      @items.size
    end

    def empty?
      @items.empty?
    end

    def clear_completed
      completed_ids = completed.map(&:id)
      completed_ids.each { |id| @items.delete(id) }
      completed_ids.size
    end

    def to_h
      {
        next_id: @next_id,
        items: @items.values.map(&:to_h)
      }
    end

    def self.from_h(hash)
      list = new
      list.instance_variable_set(:@next_id, hash["next_id"] || 1)
      items = {} #: Hash[Integer, Item]
      (hash["items"] || []).each do |item_hash|
        item = Item.from_h(item_hash)
        items[item.id] = item
      end
      list.instance_variable_set(:@items, items)
      list
    end
  end

  class Storage
    def initialize(path)
      @path = path
    end

    def load
      return List.new unless File.exist?(@path)

      data = File.read(@path)
      hash = JSON.parse(data)
      List.from_h(hash)
    rescue JSON::ParserError
      List.new
    end

    def save(list)
      dir = File.dirname(@path)
      FileUtils.mkdir_p(dir) unless File.directory?(dir)
      File.write(@path, JSON.pretty_generate(list.to_h))
    end
  end

  class Formatter
    PRIORITY_SYMBOLS = {
      low: "○",
      normal: "●",
      high: "◆"
    }.freeze

    def format_item(item, show_id: true)
      checkbox = item.completed? ? "[x]" : "[ ]"
      priority = PRIORITY_SYMBOLS.fetch(item.priority, "●")
      tags_str = item.tags.empty? ? "" : " #{item.tags.map { |t| "##{t}" }.join(" ")}"

      parts = [] #: Array[String]
      parts << "#{item.id}." if show_id
      parts << checkbox
      parts << priority
      parts << item.title
      parts << tags_str unless tags_str.empty?

      parts.join(" ")
    end

    def format_list(items, title: nil)
      lines = [] #: Array[String]
      lines << "#{title}:" if title
      lines << "(no items)" if items.empty?
      items.each do |item|
        lines << "  #{format_item(item)}"
      end
      lines.join("\n")
    end

    def format_stats(list)
      total = list.size
      done = list.completed.size
      pending = list.pending.size

      priorities = [:high, :normal, :low].map do |p|
        count = list.by_priority(p).size
        "#{p}: #{count}"
      end

      [
        "Total: #{total} (#{done} done, #{pending} pending)",
        "By priority: #{priorities.join(", ")}"
      ].join("\n")
    end
  end

  class CLI
    COMMANDS = %w[add list done undone delete clear search stats help version].freeze

    def initialize(storage_path: nil)
      path = storage_path || default_storage_path
      @storage = Storage.new(path)
      @formatter = Formatter.new
      @list = @storage.load
    end

    def run(args)
      command = args.shift || "list"

      unless COMMANDS.include?(command)
        puts "Unknown command: #{command}"
        puts "Run 'todo help' for usage"
        return 1
      end

      result = send("cmd_#{command}", args)
      @storage.save(@list)
      result
    rescue StandardError => e
      puts "Error: #{e.message}"
      1
    end

    private

    def default_storage_path
      File.join(ENV["HOME"] || "~", ".todo.json")
    end

    def cmd_add(args)
      if args.empty?
        puts "Usage: todo add <title> [--priority=high|normal|low] [--tags=tag1,tag2]"
        return 1
      end

      options = parse_options(args)
      title = args.join(" ")

      if title.empty?
        puts "Title is required"
        return 1
      end

      priority = (options["priority"] || "normal").to_sym
      tags = (options["tags"] || "").split(",").map(&:strip).reject(&:empty?)

      item = @list.add(title, priority: priority, tags: tags)
      puts "Added: #{@formatter.format_item(item)}"
      0
    end

    def cmd_list(args)
      options = parse_options(args)

      items = if filter = options["filter"]
        case filter
        when "pending" then @list.pending
        when "completed", "done" then @list.completed
        else @list.to_a
        end
      elsif priority = options["priority"]
        @list.by_priority(priority.to_sym)
      elsif tag = options["tag"]
        @list.by_tag(tag)
      else
        @list.to_a
      end

      puts @formatter.format_list(items, title: "Todo")
      0
    end

    def cmd_done(args)
      id = args.first&.to_i
      unless id && id > 0
        puts "Usage: todo done <id>"
        return 1
      end

      if item = @list.find(id)
        item.complete!
        puts "Completed: #{@formatter.format_item(item)}"
        0
      else
        puts "Item not found: #{id}"
        1
      end
    end

    def cmd_undone(args)
      id = args.first&.to_i
      unless id && id > 0
        puts "Usage: todo undone <id>"
        return 1
      end

      if item = @list.find(id)
        item.uncomplete!
        puts "Uncompleted: #{@formatter.format_item(item)}"
        0
      else
        puts "Item not found: #{id}"
        1
      end
    end

    def cmd_delete(args)
      id = args.first&.to_i
      unless id && id > 0
        puts "Usage: todo delete <id>"
        return 1
      end

      if item = @list.delete(id)
        puts "Deleted: #{@formatter.format_item(item)}"
        0
      else
        puts "Item not found: #{id}"
        1
      end
    end

    def cmd_clear(args)
      count = @list.clear_completed
      puts "Cleared #{count} completed item(s)"
      0
    end

    def cmd_search(args)
      query = args.join(" ")
      if query.empty?
        puts "Usage: todo search <query>"
        return 1
      end

      items = @list.search(query)
      puts @formatter.format_list(items, title: "Search results for '#{query}'")
      0
    end

    def cmd_stats(args)
      puts @formatter.format_stats(@list)
      0
    end

    def cmd_help(args)
      puts <<~HELP
        Todo CLI v#{VERSION}

        Usage: todo <command> [options]

        Commands:
          add <title> [options]   Add a new todo item
            --priority=PRIORITY   Set priority (high, normal, low)
            --tags=TAG1,TAG2      Add tags

          list [options]          List todo items
            --filter=FILTER       Filter by: pending, completed
            --priority=PRIORITY   Filter by priority
            --tag=TAG             Filter by tag

          done <id>               Mark item as completed
          undone <id>             Mark item as not completed
          delete <id>             Delete an item
          clear                   Remove all completed items
          search <query>          Search items by title
          stats                   Show statistics
          help                    Show this help
          version                 Show version
      HELP
      0
    end

    def cmd_version(args)
      puts "Todo CLI v#{VERSION}"
      0
    end

    def parse_options(args)
      options = {} #: Hash[String, String]
      args.reject! do |arg|
        if arg.start_with?("--")
          rest = arg[2..] or next false
          parts = rest.split("=", 2)
          key = parts[0] or next false
          value = parts[1]
          options[key] = value || ""
          true
        else
          false
        end
      end
      options
    end
  end
end

if __FILE__ == $0
  cli = Todo::CLI.new
  exit cli.run(ARGV)
end
