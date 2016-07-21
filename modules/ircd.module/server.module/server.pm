# Copyright (c) 2009-16, Mitchell Cooper
#
# @name:            "ircd::server"
# @package:         "server"
# @description:     "represents an IRC server"
# @version:         ircd->VERSION
# @no_bless:        1
# @preserve_sym:    1
#
# @author.name:     "Mitchell Cooper"
# @author.website:  "https://github.com/cooper"
#
package server;

use warnings;
use strict;
use feature 'switch';
use parent 'Evented::Object';

use utils qw(col v conf notice);
use Scalar::Util qw(looks_like_number blessed);

our ($api, $mod, $me, $pool);

sub init {
    $mod->load_submodule('protocol') or return;
    $mod->load_submodule('linkage')  or return;
    return 1;
}

sub new {
    my ($class, %opts) = @_;

    # although currently unimportant, it is noteworthy that
    # ->new() is never called for the local server. it is
    # constructed manually before the server module is loaded.

    return bless {
        umodes   => {},
        cmodes   => {},
        users    => [],
        children => [],
        # if anything is added here, add to ircd.pm also.
        %opts
    }, $class;
}

# handle a server quit.
# does not close a connection; use $server->conn->done() for that.
#
# $reason = the actual reason to log and show to opers
# $why = the reason to send in user quit messages
# $quiet = do not send out notices
#
sub quit {
    my ($server, $reason, $why, $quiet) = @_;
    $why //= "$$server{parent}{name} $$server{name}";

    notice(server_quit =>
        $server->{name},
        $server->{sid},
        $server->{parent}{name},
        $reason
    ) unless $quiet;

    # all children must be disposed of.
    foreach my $serv ($server->children) {
        next if $serv == $server;
        $serv->quit('parent server has disconnected', $why);
    }

    # delete all of the server's users.
    my @users = $server->all_users;
    foreach my $user (@users) {
        $user->quit($why, 1);
    }

    $pool->delete_server($server) if $server->{pool};
    $server->delete_all_events();
    return 1;
}

# associate a letter with a umode name.
sub add_umode {
    my ($server, $name, $mode) = @_;
    $server->{umodes}{$name} = { letter => $mode };
    L("$$server{name} registered $mode:$name");
    return 1;
}

# umode letter to name.
sub umode_name {
    my ($server, $mode) = @_;
    foreach my $name (keys %{ $server->{umodes} }) {
        my $letter = $server->{umodes}{$name}{letter};
        next unless length $letter;
        return $name if $mode eq $letter;
    }
    return;
}

# umode name to letter.
sub umode_letter {
    my ($server, $name) = @_;
    return $server->{umodes}{$name}{letter};
}

# convert umodes
sub convert_umode_string {
    my ($server1, $server2, $mode_str) = @_;

    my $string = '+';                               # new (+/-)modes
    my $modes  = (split /\s+/, $mode_str, 2)[0];    # old (+/-)modes
    my $state  = 1;                                 # current state
    my $since_state;                                # changes since state change

    foreach my $letter (split //, $modes) {

        # state change.
        if ($letter eq '+' || $letter eq '-') {
            chop $string if !$since_state;
            my $new  = $letter eq '+';
            $string .= $letter if !length $string || $state != $new;
            $state   = $new;
            undef $since_state;
            next;
        }

        # translate the letter.
        my $name = $server1->umode_name($letter) or next;
        my $new  = $server2->umode_letter($name);

        # the second server does not know this mode.
        next if !length $new;

        $string .= $new;
        $since_state++;
    }

    # if we have nothing but a sign, return +.
    if (length $string == 1) {
        L("$mode_str ($$server1{name}) -> nothing at all ($$server2{name})");
        return '+';
    }

    L("$mode_str ($$server1{name}) -> $string ($$server2{name})");
    return $string;
}

# associate a letter with a cmode name.
sub add_cmode {
    my ($server, $name, $mode, $type) = @_;
    $server->{cmodes}{$name} = {
        letter => $mode,
        type   => $type
    };
    L("$$server{name} registered $mode:$name");
    return 1;
}

# cmode letter to name.
sub cmode_name {
    my ($server, $mode) = @_;
    return unless defined $mode;
    foreach my $name (keys %{ $server->{cmodes} }) {
        next unless defined $server->{cmodes}{$name}{letter};
        return $name if $mode eq $server->{cmodes}{$name}{letter};
    }
    return;
}

# cmode name to letter.
sub cmode_letter {
    my ($server, $name) = @_;
    return unless defined $name;
    return $server->{cmodes}{$name}{letter};
}

# get cmode type.
sub cmode_type {
    my ($server, $name) = @_;
    return unless defined $name;
    return $server->{cmodes}{$name}{type} // -1;
}

# convert cmodes and their parameters
sub convert_cmode_string {
    my ($server1, $server2, $mode_str, $over_protocol, $skip_status) = @_;

    my $string = '+';                       # new (+/-)modes
    my @m      = split /\s+/, $mode_str;    # old mode string parts
    my $modes  = shift @m;                  # old (+/-)modes
    my $curr_p = -1;                        # current parameter index
    my $state  = 1;                         # current state
    my $since_state;                        # changes since state change

    foreach my $letter (split //, $modes) {

        # state change.
        if ($letter eq '+' || $letter eq '-') {
            chop $string if !$since_state;
            my $new  = $letter eq '+';
            $string .= $letter if !length $string || $state != $new;
            $state   = $new;
            undef $since_state;
            next;
        }

        # find the mode.
        my $name = $server1->cmode_name($letter) or next;

        # this mode takes a parameter.
        my $takes_param;
        if ($server1->cmode_takes_parameter($name, $state)) {
            $curr_p++;
            $takes_param++;
        }

        # skip this mode maybe if $skip_status.
        my $is_status = $server1->cmode_type($name) == 4;
        if ($skip_status && $is_status) {
            delete $m[$curr_p];
            next;
        }

        # if over protocol, some parameter translate might be necessary.
        if ($over_protocol) {

            # if it's a status mode, translate the UID maybe.
            if ($is_status && length $m[$curr_p]) {
                my $user    = $server1->uid_to_user($m[$curr_p]);
                $m[$curr_p] = $server2->user_to_uid($user) if $user;
            }

        }

        # translate the letter.
        my $new = $server2->cmode_letter($name);

        # the second server does not know this mode.
        # remove the parameter if it has one.
        if (!length $new) {
            delete $m[$curr_p] if $takes_param;
            next;
        }

        $string .= $new;
        $since_state++;
    }

    # if we have nothing but a sign, return +.
    if (length $string == 1) {
        L("$mode_str ($$server1{name}) -> nothing at all ($$server2{name})");
        return '+';
    }

    # join mode string and parameters
    my $new_string = join ' ', grep(length, $string, @m);

    L("$mode_str ($$server1{name}) -> $new_string ($$server2{name})");
    return $new_string;
}

# combine two mode strings, filtering repeats
# both mode strings must be POSITIVE; this does not support sign changes
sub combine_cmode_strings {
    my ($server, $mode_str_1, $mode_str_2) = @_;

    # separate into +modes and @params
    my ($modes_1, @params_1) = split /\s+/, $mode_str_1;
    my ($modes_2, @params_2) = split /\s+/, $mode_str_2;

    # now join them
    my $new = join ' ', $modes_1.$modes_2, @params_1, @params_2;

    # call ->cmode_string_difference() with an old modestring of +.
    # this will remove duplicates and extraneous signs.
    $new = $server->cmode_string_difference('+', $new, 0, 1);

    return $new;
}

# true if the mode takes a parameter in this state.
#
# returns:
# undef = unknown
#     0 = does not take parameter
#     1 = yes, takes parameter
#     2 = take parameter if present but still valid if not
#
sub cmode_takes_parameter {
    my ($server, $name, $state) = @_;
    my $keyshit = $state ? 1 : 2;
    my %params  = (
        0 => 0,         # normal        - never
        1 => 1,         # parameter     - always
        2 => $state,    # parameter_set - when setting only
        3 => 2,         # list mode     - consume parameter if present but valid if not
        4 => 1,         # status mode   - always
        5 => $keyshit   # key mode (+k) - always when setting, only if present when unsetting
    );
    return $params{ $server->{cmodes}{$name}{type} || -1 };
}

# takes a channel mode string and compares
# it with another, returning the difference.
# basically, for example,
#
#   given
#       $o_modestr = +ntb *!*@*
#       $n_modestr = +nibe *!*@* mitch!*@*
#   result
#       +ie-t mitch!*@*
#
# o_modestr = original, the original.
# n_modestr = new, the primary one that dictates.
#
# note that this is intended to be used for strings
# produced by the ircd, such as in the CUM command,
# and this does not handle stupidity well.
#
# specifically, it does not check if multiple
# parameters exist for a mode type intended to
# have only a single parameter such as +l.
#
# both mode strings MUST be in the positive (+) state;
# this method does NOT track signs because it only
# is capable of comparing two POSITIVE mode strings.
#
# also, it will not work correctly if multiple
# instances of the same parameter are in either
# string; ex. +bb *!*@* *!*@*
#
# if $combine_lists is true:
#
# all list modes are preserved; none are ever
# removed. when two servers link and the channel
# time is valid on both, the final list will be the
# combination of both lists. has no effect if
# $remove_none is true.
#
# if $remove_none is true:
#
# no modes will be removed. the resulting mode string
# will include the new modes in $n_modestr but will
# not remove any modes missing from $o_modestr.
# this is useful for when the channel TS is equal on
# two servers, in which case no modes should be unset.
#
sub cmode_string_difference {
    my ($server, $o_modestr, $n_modestr, $combine_lists, $remove_none) = @_;

    # split into modes, @params
    my ($o_modes, @o_params) = split ' ', $o_modestr;
    my ($n_modes, @n_params) = split ' ', $n_modestr;
    substr($o_modes, 0, 1)   = substr($n_modes, 0, 1) = '';

    # determine the original values. ex. $o_modes_p{b}{'hi!*@*'} = 1
    my (@o_modes, %o_modes_p);
    foreach my $letter (split //, $o_modes) {

        # find mode name and type.
        my $name = $server->cmode_name($letter) or next;
        my $type = $server->cmode_type($name);

        # this type takes a parameter.
        if ($server->cmode_takes_parameter($name, 1)) {
            defined(my $param = shift @o_params) or next;
            $o_modes_p{$letter}{$param} = 1;
            next;
        }

        # no parameter.
        push @o_modes, $letter;

    }

    # find the new modes.
    # modes_added   = modes present in the new string but not old
    # modes_added_p = same as above but with parameters

    my (@modes_added, %modes_added_p);
    foreach my $letter (split //, $n_modes) {

        # find mode name and type.
        my $name = $server->cmode_name($letter) or next;
        my $type = $server->cmode_type($name);

        # this type takes a parameter.
        if ($server->cmode_takes_parameter($name, 1)) {
            defined(my $param = shift @n_params) or next;

            # it's in the original.
            my $m = $o_modes_p{$letter};
            if ($m && $m->{$param}) {
                delete $m->{$param};
                delete $o_modes_p{$letter} if !scalar keys %$m;
            }

            # not there.
            else {
                $modes_added_p{$letter}{$param} = 1;
            }

            next;
        }

        # no parameter.

        # it's in the original.
        if ($letter ~~ @o_modes) {
            @o_modes = grep { $_ ne $letter } @o_modes;
        }

        # not there.
        else {
            push @modes_added, $letter;
        }

    }

    # at this point, anything in @o_modes or %o_modes_p is not
    # present in the new mode string but is in the old.

    # create the mode string with all added modes.
    my ($final_str, @final_p) = '';

    # add new modes found in new string but not old.
    $final_str .= '+' if scalar @modes_added || scalar keys %modes_added_p;
    $final_str .= join '', @modes_added;
    foreach my $letter (keys %modes_added_p) {
        foreach my $param (keys %{ $modes_added_p{$letter} }) {
            $final_str .= $letter;
            push @final_p, $param;
        }
    }

    # remove modes from original not found in new.
    unless ($remove_none) {
        $final_str .= '-' if scalar @o_modes || scalar keys %o_modes_p;
        $final_str .= join '', @o_modes;
        LETTER: foreach my $letter (keys %o_modes_p) {

            # if we are accepting all list modes, don't remove any.
            if ($combine_lists) {
                my $type = $server->cmode_type($server->cmode_name($letter));
                next LETTER if $type == 3;
            }

            # remove each mode or entry.
            PARAM: foreach my $param (keys %{ $o_modes_p{$letter} }) {
                $final_str .= $letter;
                push @final_p, $param;
            }
        }
    }

    return join ' ', $final_str, @final_p;
}

# convert cmodes to one or more string
#
#   $modes              changes in the form used by ->do_modes()
#   $over_protocol      whether to spit out UIDs or nicks
#   $split              whether to split it up into multiple strings
#   $organize           whether to alphabetize the output
#   $skip_checks        for internal use; whether to skip certain sanity checks
#
sub strings_from_cmodes {
    my ($server, $modes, $over_protocol, $split, $organize, $skip_checks) = @_;
    my @changes;

    # $modes has to be an arrayref.
    if (!ref $modes || ref $modes ne 'ARRAY') {
        L(
            "Modes are not in the proper arrayref form; ".
            "mode stringification aborted"
        );
        return;
    }

    # $modes has to have an even number of elements.
    if (@$modes % 2) {
        L("Odd number of elements passed; mode stringification aborted");
        return;
    }

    # add each mode to the resultant.
    MODE: while (my ($name, $param) = splice @$modes, 0, 2) {

        # extract the state.
        my $state = 1;
        my $first = \substr($name, 0, 1);
        if ($$first eq '-' || $$first eq '+') {
            $state  = $$first eq '+';
            $$first = '';
        }

        # $skip_checks is enabled when the modes were generated internally.
        # this is to improve efficiency when we're already certain it's valid.
        unless ($skip_checks) {

            # find the mode type.
            my $type = $me->cmode_type($name);
            if (!defined $type || $type == -1) {
                L("Mode '$name' is not known to this server; skipped");
                next MODE;
            }

            # if the mode requires a parameter but one was not provided,
            # we have no choice but to skip this.
            #
            # these are returned by ->cmode_takes_parameter: NOT mode types
            #     1 = always takes param
            #     2 = takes param, but valid if there isn't,
            #         such as list modes like +b for viewing
            #
            my $takes = $me->cmode_takes_parameter($name, $state) || 0;
            if (!defined $param && $takes == 1) {
                L("Mode '$name' is missing a parameter; skipped");
                next MODE;
            }

        }

        push @changes, [ $state, $name, $param ];
    }

    # if $organize is specified, put positive changes first and alphabetize.
    @changes = sort {
        my $sort;
        $sort = -1 if  $a->[0] && !$b->[0];
        $sort = 1  if !$a->[0] &&  $b->[0];
        $sort // $a->[1] cmp $b->[1]
    } @changes if $organize;


    # determine how much we can jam into one string.
    my $limit =
        !$split         ? 'inf'                                     : # no limit
         $split == 1    ? conf('channels',
            $over_protocol ? 'max_modes_per_sline' : 'max_modes_per_line'
                        )                                           : # config
         $split;    # custom amount specified as $split

    # stringify.
    my @strings;
    my ($str, @params) = '';
    my $current_state = -1;
    my $letters = 0;
    CHANGE: foreach my $change (@changes) {
        my ($state, $name, $param) = @$change;

        # start a new string.
        if ($letters >= $limit) {
            $str = join ' ', $str, @params;
            push @strings, $str;
            ($str, $letters, $current_state, @params) = ('', 0, -1);
        }

        # the state has changed.
        if ($state != $current_state) {
            $str .= $state ? '+' : '-';
            $current_state = $state;
        }

        # add the letter.
        my $letter = $server->cmode_letter($name) or next CHANGE;
        $str .= $letter;
        $letters++;

        # push the parameter.
        push @params, $server->_stringify_cmode_parameter(
            $param, $state, $over_protocol
        ) if defined $param;

    }
    if (length $str) {
        $str = join ' ', $str, @params;
        push @strings, $str;
    }

    return $split && wantarray ? @strings : $strings[0];
}

sub _stringify_cmode_parameter {
    my ($server, $param, $state, $over_protocol) = @_;

    # already a string.
    return $param if !blessed $param;

    # for users, use UID or nickname.
    if ($param->isa('user')) {
        return $server->user_to_uid($param) if $over_protocol;
        return $param->name;
    }

    # for servers, use an SID or name.
    if ($param->isa('server')) {
        # FIXME: the below is not protocol-safe
        return $param->id if $over_protocol;
        return $param->name;
    }

    # fallback to name if available.
    if ($param->can('name')) {
        return $param->name;
    }

    return $param;
}

sub is_local { shift == $me }

# sub DESTROY {
#     my $server = shift;
#     L("$server destroyed");
# }

sub children {
    my $server = shift;
    my @a;
    foreach my $serv ($pool->servers) {
        next unless $serv->{parent};
        next if $serv == $server;
        push @a, $serv if $serv->{parent} == $server;
    }
    return @a;
}

# hops to server.
sub hops_to {
    my ($server1, $server2) = @_;
    my $hops = 0;
    return $hops if $server1 == $server2;
    return -1    if $server2->{parent} == $server2;
    until (!$server2 || $server2 == $server1) {
        $hops++;
        $server2 = $server2->{parent};
    }
    return $hops;
}

sub uid_to_user {
    my ($server, $uid) = @_;
    return $server->{uid_to_user}($uid) if $server->{uid_to_user};
    return $pool->lookup_user($uid);
}

sub user_to_uid {
    my ($server, $user) = @_;
    return $server->{user_to_uid}($user) if $server->{user_to_uid};
    return $user->{uid};
}

sub set_functions {
    my ($server, %functions) = @_;
    @$server{ keys %functions } = values %functions;
}

# shortcuts

sub id       { shift->{sid}         }
sub full     { shift->{name}        }
sub name     { shift->{name}        }
sub conn     { shift->{conn}        }
sub users    { @{ shift->{users} }  }

# actual_users = real users
# global_users = all users which are propogated, including fake ones
# all_users    = all user objects, including those which are not propogated

sub actual_users {   grep  { !$_->{fake}       } shift->all_users }
sub global_users {   grep  { !$_->{fake_local} } shift->all_users }
sub all_users    {        @{ shift->{users}    }                  }

############
### MINE ###
############

# handle incoming server data.
sub handle {}

# send burst to a connected server.
sub send_burst {
    my $server = shift;
    return if $server->{i_sent_burst};
    my $time = time;

    # fire burst events.
    my $proto = $server->{link_type};
    $server->prepare(
        [ send_burst            => $time ],
        [ "send_${proto}_burst" => $time ]
    )->fire;

    $server->{i_sent_burst} = time;
    return 1;
}

# send data to all of my children.
# this actually sends it to all connected servers.
# it is only intended to be called with this server object.
sub send_children {
    my $ignore = shift;

    foreach my $server ($pool->servers) {

        # don't send to ignored
        if (defined $ignore && $server == $ignore) {
            next;
        }

        # don't try to send to non-locals
        next unless exists $server->{conn};

        # don't send to servers who haven't received my burst.
        next unless $server->{i_sent_burst};

        $server->send(@_);
    }

    return 1
}

sub sendfrom_children {
    my ($ignore, $from) = (shift, shift);
    send_children($ignore, map { ":$from $_" } @_);
    return 1;
}

# send data to MY servers.
sub send {
    my $server = shift;
    if (!$server->{conn}) {
        my $sub = (caller 1)[3];
        L("can't send data to unconnected server $$server{name}!");
        return;
    }
    $server->{conn}->send(@_);
}

# send data to a server from THIS server.
sub sendme {
    my $server = shift;
    $server->sendfrom($me->{sid}, @_);
}

# send data from a UID or SID.
sub sendfrom {
    my ($server, $from) = (shift, shift);
    $server->send(map { ":$from $_" } @_);
}

# convenient for $server->fire_command
sub fire_command {
    my $server = shift;
    return $pool->fire_command($server, @_);
}

# fire "global command" or just a command with data string.
sub fire_command_data {
    my ($server, $command, $source, $data) = @_;
    $command = uc $command;

    # remove command from data.
    if (length $data) {
        $data =~ s/^\Q$command\E\s+//i;
        $data = " :$data";
    }

    return unless $source->can('id');
    $server->sendfrom($source->id, "$command$data");
}

# CAP shortcuts.
sub has_cap    { my $c = shift->conn or return; $c->has_cap(@_)    }
sub add_cap    { my $c = shift->conn or return; $c->add_cap(@_)    }
sub remove_cap { my $c = shift->conn or return; $c->remove_cap(@_) }

$mod
