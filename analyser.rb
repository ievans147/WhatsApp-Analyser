require 'time'
require 'flammarion' # remember user must install this gem.

# TODOs:

# Add more linegraph methods
# redesign this to work with a GUI input
  # save this as an rbw file, rather than an rb file, to eliminate the command line features
# use the OCRA gem to make this into an executable, with the --no-dep-run argument
# go through for variable clarity - call all analysis parameters all_lines, own_lines or participant
# build in an omit-boring-words feature, which doesn't include i, you or any other pronouns.
# there seems to be a bug associated with the file WhatsApp Chat with Zeynep.txt - find it (script runs into error when linefinder is called afer user inputs participant choice)
# put unexceptional_percentage in general array utilities section, and call it in any appropriate methods
# organise the calling and ordering of graphical analysis methods
# create some input handling - if the file can't be found, give them a choice to find it in a Flammarion window until they tell you where a good one is. If it can't be parsed, write the problematic line to a Flammarion window. Ask them if they want to just skip the line. 

class WhatsAppAnalyser ## does this class even need to exist, really?

### central control methods ###

  def run
    preliminaries
    analyse_data
    present_data
  end

  def preliminaries
    file_to_array
    doctor_array
    @master_array = generate_master_array
    @trimmed_conversation = date_selection # select_dates
    @participants = choose_participants # select_participants
  end

  def analyse_data
    @participants.each do |participant|
      own_lines = linefinder(@trimmed_conversation, participant)
      analyse_message_frequencies(own_lines, @trimmed_conversation, participant)
      analyse_message_lengths(own_lines, participant)
      analyse_message_timings(@trimmed_conversation, participant)
      favourite_words(own_lines, participant, 20)
      prepare_graph_data(own_lines, participant) # one day, this should be prepare_graph_frequencies, and should be followed by prepare_graph_lengths and prepare_graph_timings
      # percentage_of_daily_messages(own_lines, participant)
      end
  end

  def present_data
    @line_type = (@chat_date_range.count > 62 ? 'lines' : 'lines+markers')
    @window = Flammarion::Engraving.new
    @window.puts "SUMMARIES"
    @window.table(tabulate_names + tabulate_frequency + tabulate_lengths + tabulate_timing + tabulate_names + tabulate_fav_words)
    @window.puts
    @window.puts
    @window.puts "DAILY STATISTICS\n"
    plot_words_each_day
    plot_characters_each_day
    plot_messages_each_day
    plot_message_percentage_each_day
    @window.wait_until_closed
  end


### preliminary methods ###

  def file_to_array
    file = File.open "./recent_chat.txt" # this is a relative path - it presumes that sample_chat is in the same directory as this script
    @lines = file.read.split("\n")
    file.close
  end

  def doctor_array
    remove_system_messages
    one_element_per_message # process_input_file splits messages including newlines into multiple elements; this method sticks those unusual messages back together.
  end

  def remove_system_messages
    @lines.select! { |line| line.include?(": ")} # space is important because there is colon in time
  end

  def one_element_per_message
    until @lines.all? { |line| (2009..2100).include?(line[6...10].to_i) }
      @lines.each_with_index do |e, i|
        unless (2009..2100).include?(e[6...10].to_i)
          @lines[i - 1] << (" " + e)
          @lines.delete_at i
        end # unless
      end # do end
    end # until
  end # method

  def generate_master_array
    dates = @lines.map { |line| Date.parse(line.slice(0..9))}
    times = @lines.map { |line| Time.parse(line.slice!(0..19))}
    @names = @lines.map { |line| line.slice!(/^.+?(?=: )/)}
    messages = @lines.map { |line| line.slice(2..-1)}
    @names.zip(times, dates, messages)
  end
    # format: name[0], time[1], date[2], message[3]

  def date_selection
    puts "\n\n\nthe available date-range is \n#{@master_array[0][2]} - #{@master_array[-1][2]}.\n"

    puts "If you would a specific date to start analysis from, enter it."
    puts "Otherwise, press enter.\n\n
    (format: 3rd Febuary 2001 or - same date - 2001-02-03)\n"
    start = process_date_input('') # default return is supplied argument
    return @master_array if start == ''

    puts "enter the date you would like to finish analysis at"
    finish = process_date_input(@master_array[-1][2]) # default return is last date here, but nobody will enter it anyway because they enter strings.
    puts "\nstart date: #{start} \nfinish date: #{finish}\n\n"

    @master_array.select { |line| line[2].between?(start, finish)}
  end

  def process_date_input(default_return)
    answer = gets.chomp
    if answer == default_return
      return default_return
    else
      begin
        return Date.parse(answer)
      rescue ArgumentError
        puts "unrecognised input, please retry \n"
        return process_date_input(default_return)
      end # begin end
    end # if else
  end # method

  def choose_participants
    @names.uniq!
    print_pchoice_instructions
    get_participant_choice
  end

  def print_pchoice_instructions
    puts 'if you would like data for a particular participant or participant,'
    puts 'enter their names separated by commas and spaces; alternately, enter'
    puts 'each to get data on every participant separately, all to get combined'
    puts 'data, and simply press enter to get data on both each participant'
    puts 'and all participants combined'
    puts
    puts "The participants in this chat are:\n #{@names}\n"
  end

  def get_participant_choice
    choice = gets.chomp
    if choice == '' && @names.length > 2
      @names.map { |name| Participant.new(name)} << Participant.new(@names[0..-2].join(', ') << ' and ' + @names[-1])
    elsif choice == '' && @names.length <= 2
      @names.map { |name| Participant.new(name) } << Participant.new(@names.join(' and '))
    elsif choice == 'all' && @names.length > 2
      [Participant.new(@names[0..-2].join(', ') << ' and ' + @names[-1])]
    elsif choice == 'all' && @names.length <= 2
        [Participant.new(@names.join(' and '))]
    elsif choice == 'each'
      @names.map { |name| Participant.new(name) }
    elsif choice.split(', ').all? { |name| @names.include? name }
      choice.split(', ').map { |name| Participant.new(name) }
    else
      puts 'bad input, try again'
      get_participant_choice
    end
  end

### miscellaneous analysis utilities ###

  def linefinder(array, participant)
    array.select { |line| participant.name.include? line[0]}
  end

  def averager(input_array, dates, participant)
    participant_messages = input_array.select { |line| participant.name.include? line[0] }
    (participant_messages.count / dates.count.to_f).round(1)
  end

  def unexceptional_percentage(whole, part)
    return 0 if whole == 0 # avoids ZeroDivisionError :)
    part.to_f / whole * 100
  end

  def array_to_hash(keys_array)
    Hash[keys_array.map { |element| [element, 0] } ]
    # originally this took a value_of_value paremeter, but neither empty strings
    # nor empty arrays behaved right, so I rewrote other methods to use integers
    # and this obviated the need to pass an argument.
  end

### message frequency analysis methods ###

  def analyse_message_frequencies(own_lines, all_lines, participant)
    total_messages(own_lines, participant)
    percentage_of_messages(all_lines, participant) # this will only work if called after total_messages. The latter uses data from the former.
    average_messages_per_own_day(own_lines, participant)
    average_messages_per_general_day(all_lines, participant)
    average_messages_in_daterange(all_lines, participant)
  end

  def total_messages(input_array, participant)
    participant.total_messages = input_array.count
  end

  def percentage_of_messages(input_array, participant)
    participant.percentage_of_messages = unexceptional_percentage(input_array.count.to_f, participant.total_messages).round(1)
  end

  def average_messages_per_own_day(own_lines, participant)
    days = own_lines.map { |line| line[2] }.uniq
    participant.average_messages_per_own_day = averager(own_lines, days, participant)
  end

  def average_messages_per_general_day(input_array, participant)
    days = input_array.map { |line| line[2] }.uniq
    participant.average_messages_per_general_day = averager(input_array, days, participant)
  end

  def average_messages_in_daterange(input_array, participant)
    days = input_array[0][2]..input_array[-1][2]
    participant.average_messages_in_daterange = averager(input_array, days, participant)
  end

### message length analysis methods ###

  def analyse_message_lengths(own_lines, participant)
    average_words_per_message(own_lines, participant)
    average_characters_per_message(own_lines, participant)
    total_words_in_daterange(own_lines, participant)
    total_chars_in_daterange(own_lines, participant)
  end

  def average_words_per_message(input_array, participant)
    participant.average_words_per_message = ((input_array.flat_map { |line| line[3].split}.count) / input_array.count.to_f).round(1)
  end

  def average_characters_per_message(input_array, participant)
    participant.average_characters_per_message = ((input_array.flat_map { |line| line[3].chars}.count) / input_array.count.to_f).round(1)
  end

  def total_words_in_daterange(input_array, participant)
    participant.total_words_in_daterange = (input_array.flat_map { |line| line[3].split}).count
  end

  def total_chars_in_daterange(input_array, participant)
    participant.total_chars_in_daterange = (input_array.flat_map { |line| line[3].chars}).count
  end

  # the two per_message methods here effectively just use the daterange methods; maybe you should replace all this flatmapping with calls to accessors, and make sure to call the daterange methods first ??

### message timing analysis methods ###

  def analyse_message_timings(trimmed_conversation, participant)
    wait(trimmed_conversation, participant)
    impatience(trimmed_conversation, participant)
    gappiness(trimmed_conversation, participant)
  end

  def wait(input_array, participant)
    lag = []

    input_array.each_with_index do |value, index|
      break if value == input_array[-1] # break (could also have been next) if this is the last element. Necessary because other lines reference input_array[index + 1], but if index == -1, index + 1 == nil, which causes errors.  ### possible problem: duplicate values. [0, 1, 2, 3, 2] might cause a break/next prematurely. I mean given the nature of the input_array, it's nigh-on impossible; for instance the two elements would need to contain the same Time object, so maybe it's nothing to worry about...
      next if input_array[index][0] == input_array[index + 1][0] # next if next message is sent by the same person as this message
      next unless participant.name.include? value[0] # next unless message is sent by one of the target participants
      lag << input_array[index + 1][1] - value[1] # (if conditions above are avoided) subtract the time at the next index from this index, returning some number of seconds, and then add that number of seconds onto lag
    end # do end
    participant.wait = (lag.inject(0.0) {|sum, element| sum + element} / lag.count).round # outputs an integer
  end # method

  def impatience(input_array, participant)
    own_gaps = []

    input_array.each_with_index do |value, index|
      break if value == input_array[-1]
      next unless input_array[index + 1][0] == input_array[index][0]
      next unless participant.name.include? value[0]
      own_gaps << input_array[index + 1][1] - value[1]
    end
    participant.impatience = (own_gaps.inject(0.0) {|sum, element| sum + element} / own_gaps.count).round
  end

  def gappiness(input_array, participant)
    gaps = []

    input_array.each_with_index do |value, index|
      break if value == input_array[-1]
      next unless participant.name.include? value[0]
      gaps << input_array[index + 1][1] - value [1]
    end
    participant.gappiness = (gaps.inject(0.0) {|sum, element| sum + element} / gaps.count).round
  end


### favourite words ###
  def favourite_words(input_array, participant, list_length)
    uttered_words = input_array.flat_map { |line| line[3].split}.map { |word| word.downcase}

    scoreboard = Hash[uttered_words.uniq.map { |word| [word, 0] } ]
    uttered_words.each { |word| scoreboard[word] += 1}
    participant.favourite_words = scoreboard.max_by(list_length) { |k, v| v }.map { |arr| (arr[0], arr[1] =  arr[1], arr[0]).join " " }.join("\n\n")
  end

### daily_numbers central methods ###

  def prepare_graph_data(own_lines, participant)
    @participant_date_range = (own_lines[0][2]..own_lines[-1][2]) # maybe I should make this a local var passed through a chain of arguments...
    @chat_date_range = (@trimmed_conversation[0][2]..@trimmed_conversation[-1][2])

    prepare_graph_frequencies(own_lines, participant)
    prepare_graph_lengths(own_lines, participant)
  end

  def prepare_graph_frequencies(own_lines, participant)
    messages_each_day(own_lines, participant)
    percentage_of_daily_messages(own_lines, participant)
  end

  def prepare_graph_lengths(own_lines, participant)
    words_each_day(own_lines, participant)
    characters_each_day(own_lines, participant)
  end


### daily numbers 'length' methods ###

  def words_each_day(own_lines, participant)
    counter = array_to_hash(@participant_date_range)
    own_lines.each { |line| counter[line[2]] += line[3].split.length }
    participant.words_each_day = counter.map { |k, v| [k, v] }.transpose
  end

  def characters_each_day(own_lines, participant)
    counter = array_to_hash(@participant_date_range)
    own_lines.each { |line| counter[line[2]] += line[3].length }
    participant.characters_each_day = counter.map { |k, v| [k, v] }.transpose
  end

### daily numbers 'frequency' methods ####

  def messages_each_day(own_lines, participant)
    counter = array_to_hash(@participant_date_range)
    own_lines.each { |line| counter[line[2]] += 1 }
    participant.messages_each_day = counter.to_a.transpose
  end

  def percentage_of_daily_messages(own_lines, participant)
    chat_counter = array_to_hash(@chat_date_range)
    individual_counter = array_to_hash(@chat_date_range)

    @trimmed_conversation.each { |line| chat_counter[ line[2] ] += 1 }
    own_lines.each { |line| individual_counter[line[2]] += 1 }

    participant.daily_percentage_messages = chat_counter.map do |k, v|
      [k, unexceptional_percentage(v, individual_counter[k])]
    end.transpose
  end

### daily numbers 'timing' methods ###

# Maybe someday...

### data-presentation methods ###

  def tabulate_names
    [@participants.map { |participant| participant.name.light_magenta }.prepend("")]
    # prepended empty string is the top-left block of the table
  end

  def tabulate_frequency
      [ ["\n\tMESSAGE FREQUENCY"],
        @participants.map { |participant| participant.total_messages}.prepend("total messages".cyan),
        @participants.map { |participant| "#{participant.percentage_of_messages}%"}.prepend("percentage of chat's messages".cyan),
        @participants.map { |participant| participant.average_messages_per_own_day}.prepend("average messages per day on which participant sent a message".cyan),
        @participants.map { |participant| participant.average_messages_per_general_day}.prepend("average messages per day on which a message was sent in the chat".cyan),
        @participants.map { |participant| participant.average_messages_in_daterange}.prepend("average messages sent per day during the specified date-range".cyan)
      ]
  end

  def tabulate_lengths
      [ ["\n\tMESSAGE LENGTHS"],
        @participants.map { |participant| participant.average_words_per_message}.prepend("average words per message sent".cyan),
        @participants.map { |participant| participant.average_characters_per_message}.prepend("average characters per message sent".cyan),
        @participants.map { |participant| participant.total_words_in_daterange}.prepend("total words written in specified date-range".cyan),
        @participants.map { |participant| participant.total_chars_in_daterange}.prepend("total characters written in specified date-range".cyan)]
  end

  def tabulate_timing
      [ ["\n\tMESSAGE TIMINGS"],
        @participants.map { |participant| "#{format_seconds(participant.wait)}\n(#{participant.wait} seconds)"}.prepend("average period of silence following last message in a series of one or more messages from this participant".cyan),
        @participants.map { |participant| "#{format_seconds(participant.impatience)}\n(#{participant.impatience} seconds)"}.prepend("average period of silence following messages in series of messages from this participant".cyan),
        @participants.map { |participant| "#{format_seconds(participant.gappiness)}\n(#{participant.gappiness} seconds)"}.prepend("average period of silence following a message from this participant (previous two metrics combined)".cyan)
      ]
  end

  def format_seconds(seconds)
    spare_seconds = seconds % 60
    minutes = (seconds - spare_seconds) / 60
    spare_minutes = minutes % 60
    hours = (minutes - spare_minutes) / 60
    spare_hours = hours % 24
    days = (hours - spare_hours) / 24

    if seconds >= 60**2 * 24 * 2 # 2 days in seconds
      "#{days} days, #{spare_hours} hours, #{spare_minutes} minutes and #{spare_seconds} seconds"
    elsif seconds >= 60**2 * 24
      "#{days} day, #{spare_hours} hours, #{spare_minutes} minutes and #{spare_seconds} seconds"
    elsif seconds >= 60**2 * 2
      "#{hours} hours, #{spare_minutes} minutes and #{spare_seconds} seconds"
    elsif seconds >= 60**2
      "#{hours} hour, #{spare_minutes} minutes and #{spare_seconds} seconds"
    elsif seconds >= 60 * 2
      "#{minutes} minutes and #{spare_seconds} seconds"
    elsif seconds >= 60
      "#{minutes} minute and #{spare_seconds} seconds"
    elsif seconds < 60
      "#{seconds} seconds"
    end # conditional
  end # method

  def tabulate_fav_words
    [ ["\n\tFAVOURITE WORDS"],
      @participants.map { |participant| participant.favourite_words}.prepend("favourite words".cyan)]
  end

  def plot_words_each_day
    @window.plot(@participants.map do |participant|
      {x: participant.words_each_day[0],
        y: participant.words_each_day[1],
        name: participant.name,
        mode: @line_type}
    end,
    {
    xaxis: { title: 'Day'},
    yaxis: { title: 'Words'}
    }
    )
  end

  def plot_characters_each_day
    @window.plot(@participants.map do |participant|
      {x: participant.characters_each_day[0],
        y: participant.characters_each_day[1],
        name: participant.name,
        mode: @line_type}
    end,
    {
    xaxis: { title: 'Day'},
    yaxis: { title: 'Total characters'}
    }
    )
  end

  def plot_messages_each_day
    @window.plot(@participants.map do |participant|
      {x: participant.messages_each_day[0],
        y: participant.messages_each_day[1],
        name: participant.name,
        mode: @line_type}
    end,
    {
    xaxis: { title: 'Day'},
    yaxis: { title: 'Total messages'}
    }
    )
  end

  def plot_message_percentage_each_day
    if @participants[-1].name.include?(' and ')
      participants = @participants[0..-2]
    else
      participants = @participants
    end


    data = participants.map do |participant|
      {
        x: participant.daily_percentage_messages[0],
        y: participant.daily_percentage_messages[1],
        name: participant.name,
        type: 'bar'
      }
    end

    layout = {barmode: 'stack',
      xaxis: { title: 'Day'},
      yaxis: { title: 'Percentage of day\'s messages'}}

    @window.plot(data, layout)
  end
end # class


Participant = Struct.new(
  :name,
  :total_messages,
  :percentage_of_messages,
  :average_messages_per_general_day,
  :average_messages_per_own_day,
  :average_messages_in_daterange,
  :average_words_per_message,
  :average_characters_per_message,
  :total_words_in_daterange,
  :total_chars_in_daterange,
  :favourite_words,
  :wait,
  :impatience,
  :gappiness,
  :words_each_day,
  :messages_each_day,
  :characters_each_day,
  :daily_percentage_messages,
  :daily_wait
)

WhatsAppAnalyser.new.run
