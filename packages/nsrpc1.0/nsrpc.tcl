# nsrpc.tcl --
#
#     This file implements the Tcl code for creating and
#     managing the rpc thread pool as well as procedures
#     for sending and executing rpc requests.
#
# $Id:$

package require TclCurl
package provide nsrpc 1.0

namespace eval ::nsrpc {
}

# ::nsrpc::nsInit --
#
#     Should be called when the package is required by AOLserver at startup.
#     Calls ::nsrpc::start.
#
# Args:
#     None
#
# Return:
#     Result of ::nsrpc::start

proc ::nsrpc::nsInit {} {
    return [::nsrpc::start -maxthreads 10 -minthreads 1]
}

# ::nsrpc::start --
# 
#     Starts a new Conn Thread Pool called "rpc". Registers all
#     /rpc/* requests to that pool.
#
# Arguments:
#     args (as flags): -maxthreads -minthreads -maxconns -timeout
# 
# Results:
#     1: Success
#     error: Failure
#
#     Sets the isRunning flag in the _rpc nsv.
#
# Comments:
#     If rpc is already running when you call this proc - it will update the
#     pool limits with the flags. There is no need to stop/start the service.

proc ::nsrpc::start args {
    set validFlags [list -maxthreads -minthreads -maxconns -timeout]

    if {[string match "-flags" $args]} {
        return $validFlags
    }

    if {[llength $args] && [expr [llength $args] % 2]} {
        set err "wrong number of args. Should be \"::rpc: start ?-flag value?"
        append err "...\""
        error $err
    }

    foreach {flag value} $args {
        if {[lsearch -exact $validFlags $flag] == -1} {
            error "Invalid flag \"${flag}\". Must be: ${validFlags}"
        }
    }

    # Create a rpc connection pool
    set command [concat [list ns_pools set rpc] $args]
    eval $command

    if {[::nsrpc::isRunning]} {
        ns_log debug "rpc: started: [ns_pools get rpc]"
        return 1
    }

    # Register the rpc pool to handle all GET/POSTS to /rpc/*
    ns_pools register rpc [ns_info server] GET /rpc/*
    ns_pools register rpc [ns_info server] POST /rpc/*

    # Register the ::nsrpc::do command for all GET/POSTS to /rpc/*
    ns_register_proc GET /rpc/* ::nsrpc::do
    ns_register_proc POST /rpc/* ::nsrpc::do

    nsv_set _rpc isRunning 1
    ns_log debug "rpc: started: [ns_pools get rpc]"

    return 1
}

# ::nsrpc::isRunning --
#
#     Returns the isRunning value in the _rpc nsv.
#
# Arguments:
#     None
#
# Results:
#     If the isRunning key in the _rpc nsv array does not exists a 0 is 
#     returned, if it does, the value is returned. 

proc ::nsrpc::isRunning {} {
    if {![nsv_exists _rpc isRunning]} {
        return 0
    }

    return [nsv_get _rpc isRunning]
}

# ::nsrpc::stop --
#
#     Stops rpc.  
#
# Arguments:
#     None
#
# Results:
#     The ::nsrpc::do proc is unregistered. There is no way to unregister 
#     a thread pool, so the best we can do is set the minthreads to 0 and 
#     timeout all waiting threads.    

proc ::nsrpc::stop {} {
    if {![::nsrpc::isRunning]} {
        return 1
    }

    nsv_set _rpc isRunning 0
    ns_unregister_proc GET /rpc/*
    ns_unregister_proc POST /rpc/*
    ns_pools set rpc -minthreads 0 -timeout 1
    ns_log debug "rpc: stopped"

    return 1
}

# ::nsrpc::export --
#
#     Adds a command to the list of commands that can be executed by 
#     RPC.
#
# Arguments:
#     command: The command to add, E.g. ::foo::barCommand
#
# Results:
#     1: The command has been added.
#     error: The command was not added.

proc ::nsrpc::export {command} {
    if {![llength [info commands $command]]} {
        error "No such command: $command"
    }

    nsv_lappend _rpc exported $command
    ns_log debug "rpc: exported: $command"

    return 1
}

# ::nsrpc::getExported --
#
#     Returns the list of exported commands.
#
# Arguments:
#     None.
#
# Results:
#     Returns a Tcl list of exported commands.

proc ::nsrpc::getExported {} {
    if {![nsv_exists _rpc exported]} {
        return [list]
    }
    return [nsv_get _rpc exported]
}

# ::nsrpc::isExported --
#
#     Check to see if $command is in the rpc export list.
#
# Arguments:
#     commnd: the name of the command.
# 
# Results:
#     1: The command has been exported.
#     0: The command has not been exported.

proc ::nsrpc::isExported {command} {
    if {[lsearch -exact [::nsrpc::getExported] $command] == -1} {
        return 0
    }
    return 1
}

# ::nsrpc::send --
# 
#     Sends a command to a remote server for evaluation.
#
# Arguments:
#     server: the evaluating server (with port): 
#         http://${ip/domain}:${port}
#     command: The command with args in Tcl list format:
#         [list ns_log notice "hello world"]
#     responseArrayName: The name of the response array.
#     filesAgf: files to be sent. The created tmp file paths will replace
#         the placeholders in the commnd.
#
# Results:
#     The HTTP reponse code is returned. The resultArray is upvared into 
#     $responseArrayName.
#
# Files Usage:
#     There may be times when you want to send files to the remote server
#     and use those files as args to the remote command. To do this, you first
#     set a placeholder as an arg in the command (E.g., tmpfile1).
#
#         set command [list ::file::copy tmpFile1 myNewFile.txt]
#
#     You then create the filesAgf using the placeholder name:
#
#         set filesAgf [list tmpFile1 myOriginalFile.txt]
#
#     When myOriginalFile.txt is sent to the remote server, it is placed in
#     a tmp file (E.g., /private/temp/ae2jnhf) that path will replace the arg 
#     "tmpFile1" in the command.

proc ::nsrpc::send {host port command responseArrayName {filesAgf ""}} {
    upvar $responseArrayName responseArray
    variable curlHandle

    if {![info exists curlHandle] || ![llength [info commands $curlHandle]]} {
        set curlHandle [::curl::init]
    }

    set url "http://${host}:${port}/rpc"

    $curlHandle configure -url $url -post 1 -httpversion 1.0
    $curlHandle configure -httpheader [list "Connection: keep-alive"] 
    $curlHandle configure -httppost [list name command contents $command]
    $curlHandle configure -bodyvar responseAgf -headervar responseHeaders

    if {[llength $filesAgf]} {
        foreach {arg file} $filesAgf {
            $curlHandle configure -httppost [list name $arg file $file]
            $curlHandle configure -httppost [list name file contents $arg]
        }
    }

    ns_log debug "rpc: send: ${command}: ${url}"

    if {[catch {$curlHandle perform} errorCode]} {
        error [::nsrpc::getCurlErrorAgf $errorCode]
    }
   
    set responseCode [$curlHandle getinfo responsecode]
    $curlHandle reset

    if {[catch {array set responseArray $responseAgf} error]} {
        lappend errorAgf errorString "invalid response format: ${responseAgf}"
        lappend errorAgf errorCode RPC_INVALID_RESPONSE_FORMAT
        array set responseArray $errorAgf
    }
    
    return $responseCode
}

proc ::nsrpc::getCurlErrorAgf {errorCode} {
    switch -exact $errorCode {
        3 {
            lappend errorAgf errorString "URL format error"
            lappend errorAgf errorCode CURL_URL_FORMAT_ERROR
        }
        6 {
            lappend errorAgf errorString "Could not resolve host"
            lappend errorAgf errorCode CURL_HOST_RESOLUTION_FAILED
        }
        7 {
            lappend errorAgf errorString "Failed to connect to host"
            lappend errorAgf errorCode CURL_HOST_CONNECTION_FAILED
        }
        26 {
            lappend errorAgf errorString "Could not read local file"
            lappend errorAgf errorCode CURL_FILE_READ_FAILED
        }
        default {
            lappend errorAgf errorString "Untracked RPC failure"
            lappend errorAgf errorCode CURL_UNTRACKED_FAILURE
        }
    }

    return $errorAgf
}

# ::nsrpc::do --
#
#     Evaluates the command sent by ::nsrpc::send. This proc is registerd
#     by ::nsrpc::start and will handle all requests to /rpc/*
#
# Arguments:
#     None
#
# Results:
#     The command is evaluated. The result is returned in the
#     HTTP response. If files were went - the tmp files will replace the
#     the arg placeholders. See ::nsrpc::send for more info.
#
# See Also:
#     ::nsrpc::send

proc ::nsrpc::do {} {
    ::nsrpc::setThreadName
    
    if {![llength [set command [ns_queryget command]]]} {
        lappend resultAgf errorString "command not passed"
        lappend resultAgf errorCode RPC_MISSING_PACKET
        ns_return 500 text/plain $resultAgf
        return
    }

    set commandName [lindex $command 0]

    if {![llength [info commands $commandName]]} {
        lappend resultAgf errorString "invalid command: ${commandName}"
        lappend resultAgf errorCode RPC_INVALID_COMMAND 
        ns_return 500 text/plain $resultAgf
        return
    }

    if {![::nsrpc::isExported $commandName]} {
        lappend resultAgf errorString "command is not exported: ${commandName}"
        lappend resultAgf errorCode RPC_NOT_EXPORTED 
        ns_return 500 text/plain $resultAgf
        return
    }

    if {[ns_queryexists file]} {
        foreach arg [ns_querygetall file] {
            set tmpFile [ns_getformfile $arg]
            
            if {[set index [lsearch -exact $command $arg]] == -1} {
                lappend resultAgf errorString "invalid file arg: ${arg}"
                lappend resultAgf errorCode RPC_INVALID_FILE_ARGUMENT 
                ns_return 500 text/plain $resultAgf
                return
            }

            set command [lreplace $command $index $index $tmpFile]
        }
    }

    ns_log debug "rpc: receive: ${command}"

    if {[catch {set result [eval $command]} error]} {
        lappend resultAgf errorString $error
        lappend resultAgf errorInfo $::errorInfo
        lappend resultAgf errorCode $::errorCode
        ns_return 500 text/plain $resultAgf
        return
    }

    ns_return 200 text/plain [list result $result]
}

proc ::nsrpc::setThreadName {} {
    if {![string match -rcp:* [ns_thread name]]} {
        set threadNameParts [split [ns_thread name] ":"]
        set threadNumber [string trim [lindex $threadNameParts 1] "-"]
        ns_thread name "-rpc:${threadNumber}-"
    }
}
