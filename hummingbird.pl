#!/usr/bin/perl

use LWP::Curl;
use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;
use JSON;
use Config::Simple;

my $config = "hummingbird.conf";
my $mfm_login_url = "https://myfordmobile.com/services/webLoginPS";
my $mfm_update_url = "https://www.myfordmobile.com/services/webAddCommandPS";
my $mfm_chkcmd_url = "https://www.myfordmobile.com/services/webGetRemoteCommandStatusPS";
my $DTE = 5; # miles

$cfg = new Config::Simple($config);

my $username = $cfg->param('username');
my $password = $cfg->param('password');
my $maker_key= $cfg->param('maker_key');


my $car_status = login();
my $sessionID = $car_status->{authToken};

my $commandid = update();
wait_for_op($commandid);


if( $car_status->{ELECTRICDTE} >= $DTE * 1.60934){
  stop_charging();
}


sub stop_charging{
  `curl -X POST https://maker.ifttt.com/trigger/car_charged/with/key/$maker_key`;
}


sub wait_for_op{

  $command_id = shift;
  
  my %query = (
    'SESSIONID' => $sessionID,
    'COMMANDID' => $command_id,
    'ck' => time,
    'apiLevel' => "1",
  );

  my $payload = make_payload(\%query);
  
  for($i; $i<30; $i++){

    my $req = HTTP::Request->new( 'POST', $mfm_chkcmd_url );
    $req->header( 'Content-Type' => 'application/json' );
    $req->content( $payload );

    my $lwp = LWP::UserAgent->new;
    $ret = $lwp->request( $req );

    $ret = $json->decode( $ret->{'_content'} );
    $status = $ret->{Entries}->{Entry}->{status};
  
    if($status eq 'COMPLETED'){
      return 0;
    }
    else{
      print "command status: $status\n";
      sleep 1;
    }

  }

  print "Command didn't complete after 30 seconds.\n";
  exit;

}


sub update{

  my %update = (
    'SESSIONID' => $sessionID,
    'LOOKUPCODE' => "DATA_STAT_QRY_CMD",
    'ck' => time,
    'apiLevel' => "1",
  );

  my $payload = make_payload(\%update);

  my $req = HTTP::Request->new( 'POST', $mfm_update_url );
         $req->header( 'Content-Type' => 'application/json' );
         $req->content( $payload );

         my $lwp = LWP::UserAgent->new;
         $ret = $lwp->request( $req );

         $ret = $json->decode( $ret->{'_content'} );
         return $ret->{COMMANDID};


}

sub make_payload{

  my $content = shift;
  
  $hash{'PARAMS'} = $content;
  $json =  JSON->new;
  $jsonstring = $json->encode(\%hash);

  return $jsonstring;

}

sub login{

	my %login = (
	  'emailaddress' => $username,
	  'password' => $password,
	  'peristent' => "1",
	  'ck' => time,
	  'apilevel' => "1",
	);

	my $payload = make_payload(\%login);
	
        my $req = HTTP::Request->new( 'POST', $mfm_login_url );
	$req->header( 'Content-Type' => 'application/json' );
	$req->content( $payload );

	my $lwp = LWP::UserAgent->new;
	$ret = $lwp->request( $req );

	$ret = $json->decode( $ret->{'_content'} );

	return $ret->{response};
}
