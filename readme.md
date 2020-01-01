This is a program for analysing WhatsApp chats and producing statistics. The program is launched and configured in the command line, and outputs data in a GUI. This readme covers the necessary steps for using it.

### Checking whether you have Ruby installed and installing it if not. ###

To check if you have ruby installed, run ruby -v in the command line. Macs come with Ruby 1.9, I believe. PCs do not come with Ruby installed. This program was written and tested for Ruby 2.5.

Download and install Ruby here: 
https://www.ruby-lang.org/en/documentation/installation/


### Install Flammarion ###

A gem is a program pertinent to Ruby. Once you have Ruby, you can install them by typing

	gem install gem_name

into your console. This program uses Flammarion, a GUI gem. Unless you know you have Flammarion, you don't. Furthermore, if you try to install it but already have it, nothing will happen. Install Flammarion by entering

	gem install Flammarion

and pressing enter. 


### Prepare the chat to be analysed ###

First you must get the chat onto your computer. On your phone, open WhatsApp and enter the chat you want data for. Press the three stacked dots in the top-right, then more, then export chat. Export it without media. Email it to yourself, or choose some other way to get it onto your computer.

For the program to work successfully, the chat must be:
- in the same directory as the .rb file
- named recent_chat.txt (alternately, you can edit the method file_to_array in the .rb file directly)

Finally, note that the program is not designed to recognise edited WhatsApp chats, or handle any errors that they might cause. 


### Run the program ###

There are two ways to run the program. Firstly, you should be able to double-click the .rb file. Secondly, you can run it in the command line, by navigating to its parent directory and entering

	ruby analyser.rb 
