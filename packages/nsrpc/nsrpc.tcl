################################################################################
#
# nsrpc.tcl --
#
#     This file implements the Tcl code for creating and managing the rpc 
#     thread pool as well as procedures for sending and executing rpc requests.
#
# Usage:
#     ns_ictl package require nsrpc
#     ::nsrpc::nsInit
#
# Requirements:
#     AOLserver version 4.5 or greater.
#
# $Id:$
#
################################################################################
package require TclCurl
package provide nsrpc 1.0
namespace eval nsrpc {}


################################################################################
#
# ::nsrpc::nsInit --
#
#     Calls ::nsrpc::start with config parameters. This proc should be
#     called after the package has been loaded.
#
# Arguments:
#     None
#
# Results:
#     Calls ::nsrpc::start with the configured parameters. Registers
#     ::nsrpc::stop @ server shutdown. Returns 1 or error.
#
# Configuration (optional):
#     ns_section ns/servers/${serverName}/packages/nsrpc
#         ns_param maxthreads 10       ; # The max number of rpc threads.
#         ns_param minthreads 1        ; # The min number of rpc threads.
#         ns_param threadtimeout 60    ; # Time idle before timeout.
#         ns_param maxconns 0          ; # Number of conns before die (0=off).
#         ns_param operationtimeoutms  ; # call timout in milliseconds.
#                                      ; #     This is a default timeout,
#                                      ; #     per-call timeouts can be 
#                                      ; #     passed in the call.
#
################################################################################
proc ::nsrpc::nsInit {} {
    set section "ns/server/[ns_info server]/packages/nsrpc"

    set operationtimeoutms [ns_config $section operationtimeoutms 2000]
    ::nsrpc::setDefaultTimeout $operationtimeoutms

    set maxThreads [ns_config $section maxthreads 10]
    set minThreads [ns_config $section minthreads 1]
    set threadtimeout [ns_config $section threadtimeout 60]
    set maxconns [ns_config $section maxconns 0]
    

    lappend command ::nsrpc::start -maxthreads $maxThreads -minthreads 
    lappend command $minThreads -timeout $threadtimeout -maxconns $maxconns
    eval $command

    ns_atshutdown ::nsrpc::stop 
    return 1
}


################################################################################
#
# ::nsrpc::start --
# 
#     Creates the rpc thread pool; registers the rpc URI to be handled by the
#     rpc thread pool; registers ::nsrpc::execute to the RPC URI.
#
# Arguments:
#     args (optional, as flags): -maxthreads -minthreads -timeout -maxconns
# 
# Results:
#     Creates the rpc thread pool; registers the rpc URI to be handled by the
#     rpc thread pool; registers ::nsrpc::execute to the RPC URI; Returns 1
#     or error.
#
# Comments:
#     If rpc is already running when you call this proc - it will update the
#     pool limits with the flags. There is no need to stop/start the service.
#
################################################################################
proc ::nsrpc::start args {
    set validFlags [list -maxthreads -minthreads -maxconns -timeout]

    if {[string match "-flags" $args]} {
        return $validFlags
    }

    if {[llength $args] && [expr [llength $args] % 2]} {
        set err "wrong number of args. Should be \"::nsrpc::start "
        append err "?-flag value?...\""
        error $err
    }

    foreach {flag value} $args {
        if {[lsearch -exact $validFlags $flag] == -1} {
            error "Invalid flag \"${flag}\". Must be: ${validFlags}"
        }
    }

    set command [concat [list ns_pools set rpc] $args]
    eval $command

    if {[::nsrpc::isRunning]} {
        ns_log debug "::nsrpc::start: [ns_pools get rpc]"
        return 1
    }

    ns_pools register rpc [ns_info server] GET /rpc/*
    ns_pools register rpc [ns_info server] POST /rpc/*
    
    ns_register_proc GET /rpc/* ::nsrpc::execute
    ns_register_proc POST /rpc/* ::nsrpc::execute

    nsv_set nsrpc isRunning 1
    ns_log debug "::nsrpc::start: [ns_pools get rpc]"
    
    return 1
}


################################################################################
#
# ::nsrpc::isRunning --
#
#     Returns the isRunning value in the nsrpc nsv.
#
# Arguments:
#     None
#
# Results:
#     If the isRunning key in the nsrpc nsv array does not exists a 0 is 
#     returned, if it does, the value is returned. 
#
################################################################################
proc ::nsrpc::isRunning {} {
    if {![nsv_exists nsrpc isRunning]} {
        return 0
    }

    return [nsv_get nsrpc isRunning]
}


################################################################################
#
# ::nsrpc::stop --
#
#     Stops rpc.  
#
# Arguments:
#     None
#
# Results:
#     The ::nsrpc::execute proc is unregistered. There is no way to unregister 
#     a thread pool, so the best we can do is set the minthreads to 0 and 
#     timeout all waiting threads.    
#
################################################################################
proc ::nsrpc::stop {} {
    if {![::nsrpc::isRunning]} {
        return 1
    }

    nsv_set nsrpc isRunning 0
    ns_unregister_proc GET /rpc/*
    ns_unregister_proc POST /rpc/*
    ns_pools set rpc -minthreads 0 -timeout 1
    ns_log debug "::nsrpc::stop: RPC Stopped"

    return 1
}


################################################################################
#
# ::nsrpc::export --
#
#     Adds a command to the list of commands that can be executed by 
#     RPC.
#
# Arguments:
#     command: The command to add, E.g. ::foo::barCommand or ns_log
#
# Results:
#     1: The command has been added.
#     error: The command was not added.
#
################################################################################
proc ::nsrpc::export {command} {
    if {![llength [info commands $command]]} {
        error "No such command: $command"
    }

    if {[::nsrpc::isExported $command]} {
        return 1
    }

    nsv_lappend nsrpc exported $command
    ns_log debug "::nsrpc::export: ${command}"

    return 1
}


################################################################################
#
# ::nsrpc::getExported --
#
#     Returns the list of exported commands.
#
# Arguments:
#     None.
#
# Results:
#     Returns a Tcl list of exported commands.
#
################################################################################
proc ::nsrpc::getExported {} {
    if {![nsv_exists nsrpc exported]} {
        return [list]
    }
    return [nsv_get nsrpc exported]
}


################################################################################
#
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
#
################################################################################
proc ::nsrpc::isExported {command} {
    if {[lsearch -exact [::nsrpc::getExported] $command] == -1} {
        return 0
    }
    return 1
}


#################################################################################
# ::nsrpc::setDefaultTimeout --
#
#     Sets the default timeout for all rpc calls.
#
# Arguments:
#     milliseconds: The value of the timout in milliseconds.
#
# Results:
#     The value is set in the nsrpc nsv and retuned.
#
# Note:
#     This value is only used if a timnout is not explicitly passed to the
#     ::nsrpc::call or ::nsrpc::send comamnds.
# 
# See Also:
#     ::nsrpc::call
#     ::nsrpc::send
#
################################################################################
proc ::nsrpc::setDefaultTimeout {milliseconds} {
    ns_log debug "::nsrpc::setDefaultTimeout: ${milliseconds}"
    return [nsv_set nsrpc timeoutms $milliseconds]
}


################################################################################
#
# ::nsrpc::getDefaultTimeout --
#
#     Returns the default timout for rpc calls. 
#
# Arguments:
#     None
#
# Results:
#     Returns the default timout as set in the nsrpc nsv.
#
# Note:
#     This value is only used if a timnout is not explicitly passed to the
#     ::nsrpc::call or ::nsrpc::send comamnds.
#
# See Also:
#     ::nsrpc::nsInit
#     ::nsrpc::setDefaultTimeout
#     ::nsrpc::call
#     ::nsrpc::send
#
################################################################################
proc ::nsrpc::getDefaultTimeout {} {
    return [nsv_get nsrpc timeoutms]
}


################################################################################
#
# ::nsrpc::send --
# 
#     Sends a command to a remote server for evaluation. The remote server
#     must be running this package.
#
# Arguments:
#     server: the evaluating server (with port): 
#         http://${ip/domain}:${port}
#     command: The command with args in Tcl list format:
#         [list ns_log notice "hello world"]
#     responseArrayName: The name of the response array.
#     args (optional - as flags): 
#         -timeoutms: in whole seconds.
#         -filesAgf: The files to send: See usage below.
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
#         set command [list file copy tmpFile1 myNewFile.txt]
#
#     You then create the filesAgf using the placeholder name:
#
#         set filesAgf [list tmpFile1 myOriginalFile.txt]
#
#     When myOriginalFile.txt is sent to the remote server, it is placed in
#     a tmp file (E.g., /private/temp/ae2jnhf) that path will replace the arg 
#     "tmpFile1" in the command.
#
################################################################################
proc ::nsrpc::send {server command responseArrayName {args ""}} {
    set validFlags [list -timeoutms -filesAgf]

    if {[string match "-flags" $args]} {
        return $validFlags
    }

    if {[llength $args] && [expr [llength $args] % 2]} {
        set err "wrong number of args. Should be \"::nsrpc::send server "
        append err "command responseArrayName ?-flag value?...\""
        error $err
    }

    foreach {flag value} $args {
        if {[lsearch -exact $validFlags $flag] == -1} {
            error "Invalid flag \"${flag}\". Must be: ${validFlags}"
        }

        set [string trimleft $flag "-"] $value
    }

    if {![info exists timeoutms]} {
        set timeoutms [::nsrpc::getDefaultTimeout]
    }

    upvar $responseArrayName responseArray
    variable curlhandle

    if {![info exists curlhandle] || ![llength [info commands $curlhandle]]} {
        set curlhandle [::curl::init]
    }

    $curlhandle configure -url "${server}/rpc" -post 1 -httpversion 1.0
    $curlhandle configure -httpheader [list "Connection: keep-alive"] 
    $curlhandle configure -httppost [list name command contents $command]
    $curlhandle configure -bodyvar responseAgf -headervar responseHeaders
    $curlhandle configure -timeoutms $timeoutms -maxredirs 0 -nosignal 1
    $curlhandle configure -tcpnodelay 1

    if {[info exists filesAgf]} {
        foreach {arg file} $filesAgf {
            $curlhandle configure -httppost [list name $arg file $file]
            $curlhandle configure -httppost [list name file contents $arg]
        }
    }

    ns_log debug "::nsrpc::send: ${server}: ${command}"

    if {[catch {$curlhandle perform} errorCode]} {
        $curlhandle cleanup
        error [::nsrpc::getCurlErrorAgf $errorCode]
    }

    set responseCode [$curlhandle getinfo responsecode]
    $curlhandle reset

    if {[catch {array set responseArray $responseAgf} error]} {
        lappend errorAgf errorString "invalid response format: ${responseAgf}"
        lappend errorAgf errorCode RPC_INVALID_RESPONSE_FORMAT
        array set responseArray $errorAgf
    }
    
    return $responseCode
}


################################################################################
#
# ::nsrpc::call --
#
#     Uses ::nsrpc::send to send a command to a remote server. The result
#     of the command is returned.
#
# Arguments:
#     server: the evaluating server (with port):
#         http://${ip/domain}:${port}
#     command: The command with args in Tcl list format:
#         [list ns_log notice "hello world"]
#     args (optional - as flags):
#         -timeout: in whole seconds.
#         -filesAgf: The files to send: See usage below.
#
# Results:
#     The result of the command is returned. If the remote server threw an
#     error, the error will be explitily thown.
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
#
# See Also:
#     ::nsrpc::send
#
################################################################################
proc ::nsrpc::call {server command {args ""}} {
    lappend sendCommand ::nsrpc::send $server $command responseArray 
    set responseCode [eval [concat $sendCommand $args]]

    if {![string match 200 $responseCode]} {
        set errorList [list]

        foreach key [list errorString errorInfo errorCode] {
            if {![info exist responseArray($key)]} {
                continue
            }

            lappend errorList $responseArray($key)
        }

        error [join $errorList " "]
    }

    return $responseArray(result)
}


################################################################################
#
# ::nsrpc::getCurlErrorAgf --
#
#     Returns the errorAgf for a Curl errorCode.
#
# Arguments:
#     erorrCode: The Curl error code.
#
# Results:
#     Returns the errorAgf for the given Curl errorCode as an agf. Keys
#     are errorString and errorCode (in human readable form).
#
################################################################################
proc ::nsrpc::getCurlErrorAgf {errorCode} {
    switch -exact $errorCode {
        3 {
            lappend errorAgf errorString "URL format error"
            lappend errorAgf errorCode URL_FORMAT_ERROR
        }
        6 {
            lappend errorAgf errorString "Could not resolve host"
            lappend errorAgf errorCode HOST_RESOLUTION_FAILED
        }
        7 {
            lappend errorAgf errorString "Failed to connect to host"
            lappend errorAgf errorCode HOST_CONNECTION_FAILED
        }
        26 {
            lappend errorAgf errorString "Could not read local file"
            lappend errorAgf errorCode LOCAL_FILE_READ_FAILED
        }
        28 {
            lappend errorAgf errorString "Operation timeout"
            lappend errorAgf errorCode OPERATION_TIMEOUT
            
        }
        default {
            lappend errorAgf errorString "Untracked RPC failure: ${errorCode}"
            lappend errorAgf errorCode UNTRACKED_FAILURE
        }
    }
    return $errorAgf
}


################################################################################
#
# ::nsrpc::execute --
#
#     Evaluates the command sent by ::nsrpc::send. This proc is registerd
#     by ::nsrpc::start and will handle all requests to /rpc/*
#
# Arguments:
#     None
#
# Results:
#     The "command" post var is evaluated. The result is returned in the
#     HTTP response. If files were went - the tmp files will replace the
#     the arg placeholders. See ::nsrpc::send for more info.
#
# See Also:
#     ::nsrpc::send
#
################################################################################
proc ::nsrpc::execute {} {
    ::nsrpc::setThreadName
    
    if {![llength [set command [ns_queryget command]]]} {
        lappend resultAgf errorString "command not passed"
        lappend resultAgf errorCode MISSING_PACKET
        ns_return 500 text/plain $resultAgf
        return
    }

    set commandName [lindex $command 0]

    if {![::nsrpc::isExported $commandName]} {
        lappend resultAgf errorString "command is not exported: ${commandName}"
        lappend resultAgf errorCode COMMAND_NOT_EXPORTED 
        ns_return 500 text/plain $resultAgf
        return
    }

    foreach arg [ns_querygetall file] {
        set tmpFile [ns_getformfile $arg]
            
        if {[set index [lsearch -exact $command $arg]] == -1} {
            lappend resultAgf errorString "invalid file arg: ${arg}"
            lappend resultAgf errorCode INVALID_FILE_ARGUMENT 
            ns_return 500 text/plain $resultAgf
            return
        }

        set command [lreplace $command $index $index $tmpFile]
    }

    ns_log debug "::nsrpc::execute: ${command}"

    if {[catch {set result [eval $command]} error]} {
        lappend resultAgf errorString $error
        lappend resultAgf errorInfo $::errorInfo
        lappend resultAgf errorCode $::errorCode
        ns_return 500 text/plain $resultAgf
        return
    }

    ns_return 200 text/plain [list result $result]
}


################################################################################
#
# ::nsrpc::setThreadName --
#
#     Since all conn pools have the same thread names: -conn:0- (yes there will
#     be as many -conn:0- threads as pools). I have chosen to rename the rpc
#     theads as not confuse them with the default pool's conn threads. This
#     is useful when running stats.
#
# Arguments:
#      None.
#
# Results:
#      The current thread is renamed to -rpc:*- if not alread named -rpc:*.
#
################################################################################
proc ::nsrpc::setThreadName {} {
    if {![string match -rcp:* [ns_thread name]]} {
        set threadNameParts [split [ns_thread name] ":"]
        set threadNumber [string trim [lindex $threadNameParts 1] "-"]
        ns_thread name "-rpc:${threadNumber}-"
    }
}


################################################################################
#
# ::nsrpc::queue --
#     Uses the ns_job API to asynchronously send rpc commands.
#
# Arguments:
#     -detached (optional): 
#         Execues the call in a detached thread that can be waited on.
#     args: 
#         See ::nsrpc::call   
#
# Results:
#     Create the nsrpc job queue if not already created. Queues the job.
#     returns the job id.  The job Id is used to wait on the job.
#
# Example: 
#     ::nsrpc::queue -detached 10.10.0.116:8000 [list ns_log notice foo]
#
################################################################################
proc ::nsrpc::queue {args} {
    if {![::nsrpc::queueExists]} {
        ::nsrpc::createQueue
    }

    lappend command ns_job queue

    if {[set index [lsearch $args -detached]] != -1} {
        lappend command -detached
        set args [lreplace $args $index $index]
    }
    
    lappend command nsrpc [concat ::nsrpc::call $args] 
    ns_log debug "::nsrpc::queue ${command}"

    return [eval $command]
}

proc ::nsrpc::queueExists {} {
    if {![nsv_exists nsrpc queueExists]} {
        return 0
    }
    return [nsv_get nsrpc queueExists]
}

proc ::nsrpc::createQueue {} {
    ns_job create nsrpc
    return [nsv_set nsrpc queueExists 1]
}

proc ::nsrpc::wait {queueId {timout ""}} {
    return [ns_job wait nsrpc $queueId]
}

proc ::nsrpc::cancel {queueId} {
    return [ns_job cancel nsrpc $queueId]
}
