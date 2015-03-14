# AOLserver Control Port (nscp.so) #

## Introduction ##
AOLserver includes a control port interface that can be enabled with the nscp module. The control port interface allows you to telnet to a specified host and port where you can administer the server and execute commands while the server is running; the only exceptions being the ns\_conn commands which need a connection.

## Configuration ##
An example configuration for the control port interface is shown below. Three sections of the configuration file are included. The nscp module is loaded into the /modules section for servername. The /module/nscp section defines the control port parameters, and the /module/nscp/users section defines the users who can log into the control port.
```
    # For security, use 127.0.0.1 only.
    #
    ns_section "ns/server/$server/module/nscp"
        ns_param port 9999
        ns_param address 127.0.0.1

    # The user param is "$user:$pwd".
    # $pwd is encryted using ns_crypt.
    # sample user="nsadmin", pw="x".
    #
    ns_section "ns/server/$server/module/nscp/users"
        ns_param user "nsadmin:t2GqvvaiIUbF2:"

    ns_section "ns/server/${servername}/modules"
        ns_param nscp nscp.so
```

## Usage ##
```
    [neon:~] Michael% telnet 127.0.0.1 9999
    Trying 127.0.0.1...
    Connected to localhost.
    Escape character is '^]'.
    login:nsadmin
    Password:x

    Welcome to server1 running at /usr/local/aolserver/bin/nsd (pid 7884)
    AOLserver/4.5.0 (aolserver4_5) for osx built on Jan  4 2007 at 17:11:28
    CVS Tag: $Name:  $
    server1:nscp 1> ns_time
    1168308907
    server1:nscp 2> join [lsort [info commands ns_*time*]] \n
    ns_buildsqltime
    ns_buildsqltimestamp
    ns_fmttime
    ns_gmtime
    ns_httptime
    ns_localsqltimestamp
    ns_localtime
    ns_parsehttptime
    ns_parsesqltime
    ns_parsesqltimestamp
    ns_parsetime
    ns_time
    server1:nscp 3> exit

    Goodbye!
    Connection closed by foreign host.
    [neon:~] Michael% 
```

## Best Practices ##
Type `lsort [info commands]` for a complete list of commands available to you. You can type nearly any Tcl command available to AOlserver Tcl libraries and ADPs. This includes the complete Tcl core and nearly any `ns_*` command. Type `lsort [info commands ns*]` for a sorted list of AOLserver Tcl commands.

### Useful commands: ###

`ns_shutdown` - Shuts down the server.

`ns_info uptime` - How long the server has been running.

`exit` - Exit the control port.