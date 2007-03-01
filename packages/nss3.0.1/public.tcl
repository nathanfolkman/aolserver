
# The contents of this file are subject to the AOLserver Public License
# Version 1.1 (the "License"); you may not use this file except in
# compliance with the License. You may obtain a copy of the License at
# http://aolserver.com/.
# 
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
# the License for the specific language governing rights and limitations
# under the License.
# 
# The Original Code is AOLserver Code and related documentation
# distributed by AOL.
# 
# The Initial Developer of the Original Code is America Online,
# Inc. Portions created by AOL are Copyright (C) 1999 America Online,
# Inc. All Rights Reserved.
# 
# Alternatively, the contents of this file may be used under the terms
# of the GNU General Public License (the "GPL"), in which case the
# provisions of GPL are applicable instead of those above.  If you wish
# to allow use of your version of this file only under the terms of the
# GPL and not to allow others to use your version of this file under the
# License, indicate your decision by deleting the provisions above and
# replace them with the notice and other provisions required by the GPL.
# If you do not delete the provisions above, a recipient may use your
# version of this file under either the License or the GPL.
 
package provide nss3 0.1

namespace eval ::nss3:: {
}

proc ::nss3::queue args {
    set action [lindex $args 0]
    set validFlags [list bucket object data contentType timeout]

    if {[string match -flags $action]} {
        return "-[join $validFlags " -"]"
    }

    lappend validActions createBucket writeObject
    lappend validActions getObject delete attributes

    if {[lsearch -exact $validActions $action] == -1} {
        error "Invalid action \"${action}\". Should be: ${validActions}"
    }

    ::nss3::parseArgs flagsArray [lrange $args 1 end] 

    set validFlags [list bucket object data contentType timeout]

    foreach flag [array names flagsArray] {
        if {[lsearch -exact $validFlags $flag] == -1} {
            set display "-[join $validFlags " -"]"
            error "Invalid flag \"-${flag}\". Should be: ${display}"
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

    if {![string is int -strict $timeout]} {
        set timeout [::nss3::getConfig timeout] 
    }

    if {[string is int -strict $timeout]} {
        lappend command -timeout $timeout
    }

    lappend command [::nss3::getConfig host][::nss3::getParam resource]

    if {[::nss3::debug]} {
        ns_log debug "nss3: ${command}"
        ::nss3::logRequest
    }

    ::nss3::clearRequest

    return [eval $command]
}

proc ::nss3::wait args {
    set token [lindex $args 0]
    set flags [lrange $args 1 end]

    set validFlags [list result status headers]

    if {[string equal -flags $token]} {
        return "-[join $validFlags " -"]"
    }

    ::nss3::parseArgs flagsArray $flags

    foreach flag [array names flagsArray] {
        if {[lsearch -exact $validFlags $flag] == -1} {
            set display "-[join $validFlags " -"]"
            error "Invalid flag \"-${flag}\". Should be: ${display}"
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

proc ::nss3::request args {
    set action  [lindex $args 0]
    set flagsAgf [lrange $args 1 end]

    set queueFlags [::nss3::queue -flags]
    set waitFlags [::nss3::wait -flags]
    set validFlags [concat $queueFlags $waitFlags]

    if {[string equal -flags $action]} {
        return $validFlags
    }
 
    ::nss3::parseArgs flagsArray $flagsAgf

    set queueArgs [list $action]
    set waitArgs [list]

    foreach flag [array names flagsArray] {
        if {[lsearch -exact $queueFlags "-${flag}"] != -1} {
            lappend queueArgs "-${flag}" $flagsArray(${flag})
        } elseif {[lsearch -exact $waitFlags "-${flag}"] != -1} {
            lappend waitArgs "-${flag}" $flagsArray(${flag})
        } else {
            error "Invalid flag \"-${flag}\". Should be: ${validFlags}"
        }
    }

    set token [eval [concat [list ::nss3::queue] $queueArgs]]
    return [eval [concat [list ::nss3::wait $token] $waitArgs]]
}
