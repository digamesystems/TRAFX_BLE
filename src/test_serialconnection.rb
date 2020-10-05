=begin rdoc
=Serial Connection Tester Class
==test_serialconnection.rb	

For Engineering Use. 
(To test performance of serial connection on different operating systems.)

Not a customer-facing module/class.

Copyright 2020, Digame Systems. All rights reserved.
=end

require 'io/console' # for getch
require './serialconnection' # Digame serial communication class

class TestSerialConnection< SerialConnection
 
# When scanning for a reader we need to know which OS we're running...
    def my_os
        puts RUBY_PLATFORM.to_s

        if RUBY_PLATFORM.include?("linux")
            return :linux
        end
        
        if RUBY_PLATFORM.include?("mingw32")
            return :cygwin
        end
        
        if RUBY_PLATFORM.include?("mswin32")
            return :windows
        end

        return :unknown
    end
  

  def initialize(com=nil)

    puts my_os
  	  	
  	if com.nil? 
  	   
  	  case my_os

        when :windows, :cygwin
        		
            #look for a reader on comports 1 to 20 	
            0.upto(19) do |p|
                begin
                super(p)
                puts "Device found on COM#{p+1}"
                break
                rescue Exception
                    p $!
                    puts "No device on COM#{p+1}"
                end
            end
			
        when :linux
            
            com = '/dev/ACM0'
            
            begin
                super(com)
                puts "Device found on #{com}"
            rescue Exception
                puts "No device on #{com}"
                raise 'Unable to connect to device using default linux descriptor.'
            end
				
		else #Nothing to do...
		    puts "Unknown operating system..."
		    raise 'Operating System Unknown. --Not sure how to find the device'
		      
	  end
		  
	else
		
        #try connecting to what they give us...
        begin
            super(com)
            puts "Device Found on #{com}"
        rescue Exception
            puts "No device found on #{com}."
            raise 'Unable to connect to device using supplied descriptor. --Is the device plugged in?'
        end
				
    end
  
    #send_receive("") #This will die if we failed to initialize properly...
    
  end
  
private  

def process_rx_buf(data_received)
    print data_received
    STDOUT.flush

end


    
public 

  
end

t = TestSerialConnection.new("COM5")

cmd = ""
done = false
while !done  
    cmd = STDIN.getch.upcase.gsub("\n","\r") 
    #cmd = gets.upcase.gsub("\n","") 
    # p cmd
    done = (cmd == "Q")
    unless done
        t.send(cmd)
    end
end
