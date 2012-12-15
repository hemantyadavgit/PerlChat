use strict;
use IO::Socket;
use Carp;
use Switch;
use DateTime;

##Global DateTime Hash
my %gtime = ();

##Global Session ID variable, keeps a list of session ids logged in
my @ssid;
##Global Login name variable, keeps alist of logged in users
my @glogin;
##Global Chat Buffer, stores chat data
my @chatbuffer;

##Global Hash Table, keeps a hash mapping of sessionids and usernames
my %ghash = ();

##maintains chat history length, recommended to be kept 60 (lines) or less
##MAX can be 64, as input message size on form is 64.
##If chat history of greater than 64 is requires then modify MAXLEN accordingly
my $MAXCHAT = 60;

##Server setup
my($sock, $oldmsg, $newmsg, $hisaddr, $hishost, $MAXLEN, $PORTNO);
$MAXLEN = 4096;
$PORTNO = 6700;
$sock = IO::Socket::INET->new(LocalPort => $PORTNO, Proto => 'udp')
    or die "socket: $@";
print "\nServer up and Running! Listening on Port : $PORTNO\n";
##Event loop, receives messages from client and decodes it.
while (1) {
	$sock->recv($newmsg, $MAXLEN);
    my($port, $ipaddr) = sockaddr_in($sock->peername);
    $hishost = gethostbyaddr($ipaddr, AF_INET);
    ##print "\nReceived Request from $hishost MSG:$newmsg\n";
	#Break up message
	my @slicedmsg = split(':',$newmsg);
	#Setup eventloop
	switch($slicedmsg[0])
	{
    ##Authentication Request
		case "AUTH"
		{
		if(!login($slicedmsg[1],$slicedmsg[2]))
		{
			if(!isAlreadyAuthenticated($slicedmsg[1]))
			{
				my $send_sid = generateSessionID($slicedmsg[1]);
				if($send_sid)
				{
					push(@glogin,$slicedmsg[1]);
					
					$sock->send("OK:$send_sid");
				}
			}
			else
			{
				$sock->send("DUP");
			}
		}	
		else
		{
			$sock->send("NOT OK");
		}
		}
    ##Receive Message
		case "MSG"
		{
			carp "\nIn MSG";
      ##Check is session is valid before posting message
			if(!isSessionValid($slicedmsg[1]))
			{	my $now = DateTime->now(time_zone=>'local')->datetime();
				$gtime{$slicedmsg[1]}=$now;
				my $user=$ghash{$slicedmsg[1]};
				my $cstr = "$user".":"."$slicedmsg[2]"."\n";
				push (@chatbuffer, $cstr);
        
				carp "CHAT : @chatbuffer";
				$sock->send("OK");
			}
			else
			{
				$sock->send("NOT LOGGED IN");
			}
		}
   ##Logout request
		case "LGOT"
		{
		carp "In Logout!";
   ##Again check session validity to avoid unauthorized logouts
		if(!isSessionValid($slicedmsg[1]))
			{
				##carp "Destroying!";
				my $user_n = $ghash{$slicedmsg[1]};
				destroySession($slicedmsg[1]);
				
				$sock->send("LGOT OK");
				push(@chatbuffer,"\nUser $user_n has left the room!\n");
				##carp "\nsent";
				##dumpSessionID();
			}
		else
			{
				$sock->send("LGOT NOT OK");
			}
			
		}
   ##Update request
		case "UPDT"
		{
      ##If session is valid, send chat buffer
			my $now = DateTime->now(time_zone=>'local')->datetime();
			if(!isSessionValid($slicedmsg[1]))
			{
			if(isSessionExpired($gtime{$slicedmsg[1]},$now)!=1)
			{
				my $size=scalar @chatbuffer;
				##If buffer is too big, shorten it
				if($size>$MAXCHAT)
				{
					handleChatHistory();
				}
				carp "SIZE: $size CHATBUFFER: @chatbuffer";
				$sock->send("OK::::@chatbuffer");
			}
			else
			{
				my $user_n = $ghash{$slicedmsg[1]};
				
				push(@chatbuffer,"\nUser $user_n has left the room!\n");
				$sock->send("TIMEOUT::::Your Session has timed out!");
				destroySession($slicedmsg[1]);
			}
				
		}
		}
		else
		{
			$sock->send("UPDT NOT OK");
		}
	}
} 
die "recv: $!";

##Handles login. Currently this feauture is file driven, can be made database driven
sub login()
{
	open(MYINPUTFILE, "pwd.txt");
	while(<MYINPUTFILE>)
	{
		my($line) = $_;
		chomp($line); ##Remove Newlines
		my @slicedline = split(':',$line);
		if(($slicedline[0] eq $_[0])&&($slicedline[1] eq $_[1]))
		{
			
			return 0;
		}
	}
	return 1;
 }
 
##generates sessionIDs 
sub generateSessionID()
{
	my $session_id = int(rand(10000000)-rand(100000));
	push(@ssid, $session_id);
	$ghash{$session_id}=$_[0];
	my $dt=DateTime->now(time_zone=>'local')->datetime();
	$gtime{$session_id}=$dt;
	carp "\nSession ID $session_id Generated";
	return $session_id;
}
##Destroyes session on logout, deletes corrosponding entries
sub destroySession()
{
	my $index = 0;
	my $t_name = $ghash{$_[0]};
	##carp "$t_name";
	delete $ghash{$_[0]};
	$index++ until $ssid[$index] eq $_[0];
	splice(@ssid, $index, 1);
	$index=0;
	$index++ until $glogin[$index] eq $t_name;
	splice(@glogin, $index, 1);
	##carp "\n LOGGED IN NAMES :@glogin";
	
	
}
##checks if given sessionID is valid
sub isSessionValid()
{
	foreach(@ssid)
	{
		if($_ eq $_[0])
		{
			return 0;
		}
	}
	return 1;
}
##Dumps all sessionIDs for debugging purposes only
sub dumpSessionID()
{
	
	{
		carp "\nSession ID Dump : @ssid";
	}
}
##Checks if a user is already authenticated
sub isAlreadyAuthenticated()
{
	foreach(@glogin)
	{
		if($_ eq $_[0])
		{
			return 1;
		}
	}
	return 0;
}
##handles chat history, maintains chatbuffersize 
sub handleChatHistory()
{
  my $count;
  for ($count = 10; $count >= 1; $count--)
  {
    shift(@chatbuffer);
  }
}

##checks if session timed out
sub isSessionExpired()
{
	my $old_time = shift;
	my $new_time = shift;
	print "old time: $old_time\n";
	print "new time: $new_time\n";

	$old_time =~ /(.*)-(.*)-(.*)T(.*):(.*):(.*)/;
	my $old_year = $1;
	my $old_month = $2;
	my $old_day = $3;
	my $old_hours = $4;
	my $old_minutes = $5;
	my $old_seconds = $6;
	$new_time =~ /(.*)-(.*)-(.*)T(.*):(.*):(.*)/;
	my $new_year = $1;
	my $new_month = $2;
	my $new_day = $3;
	my $new_hours = $4;
	my $new_minutes = $5;
	my $new_seconds = $6;

	if (($old_year != $new_year) || ($old_month != $new_month) || ($old_day != $new_day) || ($old_hours != $new_hours))
	{
		return 1;
	}
	elsif ($old_minutes + 5 < $new_minutes)
	{
		return 1;
	}
	else
	{
		return 0;
	}
}