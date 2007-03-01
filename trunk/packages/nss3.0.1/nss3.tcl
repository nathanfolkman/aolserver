#
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
#
# -----------------------------------------------------------------------------
#
# This package uses a namespace variable to hold configuration options. These 
# options will persist for the life of the thread or conn. See the README file
# for more information about setting the configuration options after runnign 
# package require.
# 
# The package also uses a global array to hold the request parameters and
# headers.  This array will be cleaned up after the connection.  It is also 
# explicitly cleaned up at the end of nss3::queue by nss3::cleanRequest.
# 
# The only procs that are public are nss3::queue and nss3::wait.  The other 
# procs are internal and should be considered private.
#

package require sha1
package require md5
package require base64

package provide nss3 0.1

namespace eval ::nss3:: {
    variable config
    set config(host) http://s3.amazonaws.com
    set config(timeout) 2
    set config(debug) 0

    namespace export queue
    namespace export wait
}

proc ::nss3::setConfig {name value} {
    variable config
    set config(${name}) $value
}

proc ::nss3::getConfig {name} {
    variable config
    if {![info exist config(${name})]} {
        return ""
    }
    return $config(${name})
}

proc ::nss3::setParam {name value} {
    global request
    set request(param.${name}) $value 
}

proc ::nss3::getParam {name} {
    global request 
    if {![info exist request(param.${name})]} {
        return ""
    }
    return $request(param.${name})
}

proc ::nss3::setHeader {name value} {
    global request
    set request(header.${name}) $value
}

proc ::nss3::getHeader {name} {
    global request
    if {![info exist request(header.${name})]} {
        return ""
    }
    return $request(header.${name})
}

proc ::nss3::buildAuthHeader {} {
    foreach param [list method body resource] {
        set $param [getParam $param]
    }

    foreach header [list Date Content-Type Content-md5] {
        set $header [getHeader $header]
    }

    set x-amzHeaders [list]

    foreach header [lsort [headerNames x-amz-*]] {
        set value [getHeader $header]
        lappend x-amzHeaders "${header}:${value}"
    }

    set signatureParts [list $method ${Content-md5} ${Content-Type} $Date]

    if {[llength ${x-amzHeaders}]} {
        lappend signatureParts [join ${x-amzHeaders} "\n"]
    }

    lappend signatureParts $resource 
    setParam signatureParts $signatureParts

    set signatureString [join $signatureParts "\n"]
    set signature [::sha1::hmac [getConfig privateKey] $signatureString]
    set signature [binary format H* $signature]
    set signature [string trim [::base64::encode $signature]]

    return "AWS [getConfig publicKey]:${signature}"
}

proc ::nss3::createRequest {action bucket object data contentType} {
    switch -exact $action {
        createBucket {
            setParam method PUT
            setParam resource /${bucket}
        }
        writeObject {
            setParam method PUT
            setParam body $data
            setParam resource /${bucket}/${object}
            setHeader Content-Type $contentType
            setHeader x-amz-meta-title $object
            setHeader Content-md5 [::base64::encode [::md5::md5 $data]] 
            setHeader Content-Length [string length $data]    
        }
        getObject {
            setParam method GET
            setParam resource /${bucket}/${object}
        }
        deleteObject {
            setParam method DELETE
            setParam resource /${bucket}/${object}
        }
        deleteBucket {
            setParam method DELETE
            setParam resource /${bucket}
        }
    }

    set dateFormat "%a, %d %b %Y %T %Z"
    set timestamp [clock format [clock seconds] -format $dateFormat]

    setHeader Date $timestamp
    setHeader Authorization [buildAuthHeader]
}

proc ::nss3::queue args {
    set action [lindex $args 0]

    lappend validActions createBucket writeObject
    lappend validActions getObject deleteObject deleteBucket

    if {[lsearch -exact $validActions $action] == -1} {
        error "Invalid action \"${action}\". Should be: ${validActions}"
    }

    set args [lrange $args 1 end]
    parseArgs argArray $args

    set validFlags [list bucket object data contentType timeout]

    foreach flag [array names argArray] {
        if {[lsearch -exact $validFlags $flag] == -1} {
            error "Invalid flag \"${flag}\". Should be: ${validFlags}"
        }
    }

    foreach flag [list bucket object data contentType timeout] {
        if {![info exists argsArray(${flag})]} {
            set $flag ""
            continue
        }
        set $flag $argsArray(${flag})
    }
   
    createRequest $action $bucket $object $data $contentType

    set requestHeaders [ns_set create]

    foreach header [headerNames] {
        set value [getHeader $header]
        ns_set put $requestHeaders $header $value
    }

    lappend command ns_http queue -method [getParam method] 
    lappend command -headers $requestHeaders -body [getParam body]

    if {[string is int -strict $timeout]} {
        lappend command -timeout $timeout
    }

    lappend command [getConfig host][getParam resource]
  
    if {[debug]} {
        set requestObject [printRequest]
        ns_log debug "nss3: ${command}\n${requestObject}"
    }

    clearRequest
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

proc ::nss3::debug {} {
    if {![string length [set v [getConfig debug]]] || ![string is int $v]} {
        return 0
    }
    return $v
}

proc ::nss3::headerNames {{pattern ""}} {
    global request
    lappend command array names request

    if {[string length $pattern]} {
        lappend command "header.${pattern}"
    } else {
        lappend command header.*
    }

    set nameList [eval $command]
    set returnList [list]

    foreach name $nameList {
       lappend returnList [lindex [split $name "."] 1]
    }

    return $returnList
}

proc ::nss3::printRequest {} {
    global request
    set output [list]

    foreach key [lsort [array names request]] {
        set value $request(${key})
        lappend output "${key}: ${value}"
    }

    return [join $output \n]
}

proc ::nss3::clearRequest {} {
    global request
    array unset request
}

proc ::nss3::parseArgs {arrayName argList} {
    upvar $arrayName argsArr

    set i 0
    set args [split $argList]

    foreach arg $args {
        if {[regexp {^-([A-Z][a-z])*} $arg]} {
            set value [lindex $args [expr $i + 1]]
            set key [string range $arg 1 end]

            if {[regexp {^-([A-Z][a-z])*} $value]} {
                set value ""
            }

            set argsArr($key) $value
        }

        incr i
    }
}
