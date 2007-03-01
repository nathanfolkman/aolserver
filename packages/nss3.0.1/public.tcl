package provide nss3 0.1
namespace eval ::nss3:: {}

proc ::nss3::queue args {
    set action [lindex $args 0]

    lappend validActions createBucket writeObject
    lappend validActions getObject delete attributes

    if {[lsearch -exact $validActions $action] == -1} {
        error "Invalid action \"${action}\". Should be: ${validActions}"
    }

    ::nss3::parseArgs flagsArray [lrange $args 1 end] 
    set validFlags [list bucket object data contentType timeout]

    foreach flag [array names flagsArray] {
        if {[lsearch -exact $validFlags $flag] == -1} {
            error "Invalid flag \"${flag}\". Should be: ${validFlags}"
        }
    }

    foreach flag [list bucket object data contentType timeout] {
        if {![info exists flagsArray(${flag})]} {
            set $flag ""
            continue
        }
        set $flag $flagsArray(${flag})
    }

    if {![string length $contentType]} {
        set contentType text/plain
    }

    ::nss3::createRequest $action $bucket $object $data $contentType

    set requestHeaders [ns_set create]

    foreach header [::nss3::headerNames] {
        set value [::nss3::getHeader $header]
        ns_set put $requestHeaders $header $value
    }

    lappend command ns_http queue -method [::nss3::getParam method]
    lappend command -headers $requestHeaders

    if {[string length [::nss3::getHeader Content-Length]]} {
        lappend command -body [::nss3::getParam body]
    }

    if {[string is int -strict $timeout]} {
        lappend command -timeout $timeout
    }

    lappend command [::nss3::getConfig host][::nss3::getParam resource]

    if {[::nss3::debug]} {
        set requestObject [::nss3::printRequest]
        ns_log debug "nss3: ${command}\n${requestObject}"
    }

    ::nss3::clearRequest
    return [eval $command]
}

proc ::nss3::wait args {
    set token [lindex $args 0]
    set flags [lrange $args 1 end]

    parseArgs flagsArray $flags
    set validFlags [list result status headers]

    foreach flag [array names flagsArray] {
        if {[lsearch -exact $validFlags $flag] == -1} {
            error "Invalid flag \"${flag}\". Should be: ${validFlags}."
        }
    }

    lappend command ns_http wait

    if {[info exists flagsArray(result)]} {
        upvar $flagsArray(result) resultVar
        lappend command -result resultVar
    }

    if {[info exists flagsArray(status)]} {
        upvar $flagsArray(status) statusVar
        lappend command -status statusVar
    }
    
    if {[info exists flagsArray(headers)]} {
        lappend command -headers $flagsArray(headers)
    }

    lappend command $token

    return [eval $command]
} 
