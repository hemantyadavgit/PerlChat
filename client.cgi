#!/soft/perl5.8.7/bin/perl -w
use IO::Socket;
use strict;
use Switch;
use CGI::Carp qw(fatalsToBrowser);
use CGI qw(:standard);
use warnings;

my $query=CGI->new;

sub main()
{		
	
	
	##print "Context-type: text/plain\n\n"."Action Here".$query->param("action");
		if ($query->param("action") eq "login")
		{
			
			handleLogin();
		}
		
		elsif($query->param("action") eq "logout")
		{
			handleLogout();
		}
		
		elsif($query->param("action") eq "sendmsg")
		{
			
			##print "Context-type: text/plain\n\n"."In send!";
			handleSend();
		}
		elsif($query->param("action") eq "update")
		{
			handleUpdate();
		}
		
		
		else
		{
		dumpHTML();
		}
	
}
			
			
			
##sends message to server			
sub sendToServer
{
printf "In Send Server";
my($sock, $server_host, $buf, $port, $ipaddr, $hishost, 
   $MAXLEN, $PORTNO, $TIMEOUT);
$buf         = $_[0];
$server_host = $_[1];
$PORTNO  = $_[2];
$MAXLEN  = 4096;
$TIMEOUT = 5;



$sock = IO::Socket::INET->new(Proto     => 'udp',
                              PeerPort  => $PORTNO,
                              PeerAddr  => $server_host)
    or die "Creating socket: $!\n";

$sock->send($buf) or die "send: $!";

eval {
    local $SIG{ALRM} = sub { die "alarm time out" };
    alarm $TIMEOUT;
    $sock->recv($buf, $MAXLEN)      or die "recv: $!";
    alarm 0;
    1;  # return value from eval on normalcy
} or die "recv from $server_host timed out after $TIMEOUT seconds.\n";

return $buf;
}

##Logs in user
sub handleLogin
{
	my $username=$query->param('username');
	my $password=$query->param('password');
	my $hostaddr=$query->param('host');
	my $hostport=$query->param('port');
	my $sendstring="AUTH:"."$username".":"."$password";
	my $response=sendToServer($sendstring,$hostaddr,$hostport);
	my @s_response=split(':',$response);
	
	if($s_response[0] eq "OK")
	{
		print "Context-type: text/plain\n\n"."$s_response[1]";
	}
	elsif($s_response[0] eq "NOT OK")
	{
		print "Context-type: text/plain\n\n"."failed";
	}
	else
	{
	print "Context-type: text/plain\n\n"."DUP";
	}
}

##Sends Logout request
sub handleLogout
{
 my $sendstring="LGOT:".$query->param('session').":";
 my $hostaddr=$query->param('host');
 my $hostport=$query->param('port');
 my $response=sendToServer($sendstring,$hostaddr,$hostport);
 print "Context-type: text/plain\n\n"."$response";
}
##Sends data to server
sub handleSend
{
 my $sendstring="MSG:".$query->param('session').":".$query->param('send').":";
 my $hostaddr=$query->param('host');
 my $hostport=$query->param('port');
 my $response=sendToServer($sendstring,$hostaddr,$hostport);
 ##print "Context-type: text/plain\n\n"."This is Response$response";
 if($response eq "OK")
 {
 handleUpdate();
 }
}
##Gets data from chatbuffer from server
sub handleUpdate
{
	my $sendstring="UPDT:".$query->param('session').":";
	my $hostaddr=$query->param('host');
	my $hostport=$query->param('port');
	my $response=sendToServer($sendstring,$hostaddr,$hostport);
  my @s_response=split('::::',$response);
  if ($s_response[0]=="OK")
  {
	print "Context-type: text/plain\n\n"."$s_response[1]";
  }
}

##outputs HTML file
sub dumpHTML()
{
	print "Content-type: text/html\n\n";
	open HANDLE, "./form.html" or die($!);
 	print while <HANDLE>;
	close HANDLE;
}
main();