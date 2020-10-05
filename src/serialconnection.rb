=begin rdoc
=Thinkify Serial Connection Class
==serialconnection.rb	

Serialconnection is a threaded listener that handles connections and basic message parsing to/from Thinkify readers.

Copyright 2011, Thinkify LLC. All rights reserved.
=end

require "rubygems"
require "serialport"
require 'timeout'

class SerialConnection 
  
  attr_accessor :raise_errors
  attr_accessor :debug_com

  def initialize(comport)   
    
    @msg_terminator = "\r\n"

    #So we can analyze message traffic if we want
    @debug_com = false
    
    #Try to open the port. -- If it fails it will throw an error.
    if @debug_com 
        puts "Opening Com Port: " + comport
    end

    @sp = SerialPort.new(comport, 115200, 8, 1, SerialPort::NONE)	
 
    if @debug_com 
        p @sp.to_s
    end

    @sp.read_timeout=-1

    #POSIX systems don't support...
    begin
      @sp.write_timeout=-1
    rescue Exception
      if @debug_com
        puts "POSIX System detected."
        #puts "**********************"
      end
    end

    #throw an error on reader "error" messages
    @raise_errors=true
          
    #Where we store incoming data
    @rx_buf = ""  
        
    #Mutex so rx_buf doesn't get screwed up w/ multi-threaded access
    @mutex = Mutex.new
    
    #Serial RX Listener
    @rx_thread = Thread.new {self.listen}
    @rx_thread.priority +=1


  
    #Look for a reader by asking for its firmware version. If we don't see one, we'll throw an error.
    timeout(10) {
      send("Z")	
    }
    
  end


  #Create a thread to listen for data on the serial port from the reader module. Call only once from the initialize routine!
  def listen
    
    while (1) do
    
      begin 
        #switched to readpartial to see if it does a better job keeping up w/streaming data. It seems not to...
        #ch = @sp.getc
        ch = @sp.readpartial(1024)
        #p ch
      rescue
      #an interesting difference between linux and windows, here. 
      #apparently, if there's nothing in the serial buffer, windows will
      #throw and eof error every time through the loop. 
      #Under Ubuntu, It looks like the .readpartial above blocks until 
      #there is data. (I never hit here...)
        #puts "Error: #{$!}"
        #puts "Error on readpartial in listen:"
        #puts "ch"
        #p ch
        #puts "rx_buf"
        #p @rx_buf
        #puts "---"
        ch=nil 
      end
           
      if !ch.nil? 
  
        @mutex.synchronize {          
          #append the data to the receive buffer. 
          @rx_buf << ch 
	    }  
          
        # Give decendents a chance to do something with this data.
        process_rx_buf(ch)
    	
      else # no data. -- rest a bit...
        #Under windows, without a sleep and a read timeout of -1, this thread really chews up cpu. Linux seems to be blocking on the .readpartial above...
        #puting the sleep here, where we've checked that there was no data on the last call to getc, seems to really help and doesn't impact performance much at all... 	
              
        sleep(0.05) 
          
        #print "*"# "nil"
      end
                
    end
       
  end


  #Called by listen when one or more lines of text have been returned. For children to overload to do their own processing of the data coming in.
  def process_rx_buf(data_received)
  end
  
  #shoot a message to the module. <CR> terminated.
  def send(s)
    
    s=s.to_s
    
    if @debug_com 
      print "Sending: #{s}\r\n"
    end
    
    @sp.write("#{s}")# + @msg_terminator)   
    
  end
  
  
  #Scan the RX buffer until we see a "\nREADY>" prompt indicating the reply is done.
  #This is used in command-response mode. See: send_receive
  def receive
  
    while !@rx_buf.include?(@msg_terminator) do
      #spin till a complete message comes in 
      #-- We're probably going to need a com timeout here...
      sleep(0.01)	  
    end
      
    #extract the payload of the reply and get rid of the "READY>" prompts...  
    #puts "in receive. Raw Receive Buffer:"
    #p @rx_buf
    
    retval = ""
    
    if @rx_buf == @msg_terminator #response to an empty string
      retval == ""
    else
      retval= @rx_buf.strip[0..(@rx_buf.index(@msg_terminator)-1)]
    end
  
    if @debug_com 
      print "Received: #{retval}\r\n"
    end
    
    @mutex.synchronize{
      @rx_buf = ""
    }
    
    if retval.include? "UNKNOWN"
      raise retval if @raise_errors
    end
  
    return retval
    
  end
  
  
  #Executes a synchronous command-response transaction w/the module.
  def send_receive(s)
      #puts "in send_receive. Sending:"
      #p s 
  
      @mutex.synchronize{
        #Clear the receive buffer before we send a message
        @rx_buf=""
      }
      
      begin
        #Fire off a message
        send(s)
        #Wait for the reply
        receive
        
      rescue
        raise "Trouble in SerialConnection.send_receive. Sent: #{s}. Got: #{$!}"
      end

  end
  

  #shut down the serial port.
  def close
    @rx_thread.join
    @sp.close
  end
  
end
