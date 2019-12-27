The program works by executing a single method, run, which then branches out into many other methods.

The run method contains three methods - preliminaries, analyse_data, and present_data, each of call a series of sub-methods.

Preliminaries accesses a hardcoded relative filepath, turns the file it finds into an array of strings, sorts out erros introduced by splitting by '\n', and then generates another array, deceptively called @master_array, from the strings. @master_array is an array of tuples, or sub-arrays, each one corresponding to a message. A given tuple contains the sender's name, a time object, a date object, and the message text. 

From @master_array, a method finds the unique participants and the start and end date of the chat. Other methods get CLI user input to choose which participants and dates to analyse for. @trimmed_array is created from @master_array, and selects-out all messages outside the date-range. @master_array is no longer relevant. For each participant the user identifies by name, including 'all combined', a Participant object is created, and their name is assigned to its name attribute. These Person objects are placed inside an @participants array. 

This marks the end of the preliminaries. Analyse_data is the next stage. It loops over @participants, passing a variable called participant to a number of methods that assign data to the given participant's accessors, and which access @trimmed_array, typically looking for tuples whose 0th element is the same as participant.name . 

present_data then initialises a GUI object called @window. present_data calls a variety of tabulation and plotting methods on @window that, again, iterate over @participants to create data structures that can be processed by @window.table() and @window.plot() . 