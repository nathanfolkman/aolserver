package provide nss3 0.1
namespace eval ::nss3:: {}

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
        set $param [::nss3::getParam $param]
    }

    foreach header [list Date Content-Type Content-MD5] {
        set $header [::nss3::getHeader $header]
    }

    set x-amzHeaders [list]

    foreach header [lsort [::nss3::headerNames x-amz-*]] {
        set value [::nss3::getHeader $header]
        lappend x-amzHeaders "${header}:${value}"
    }

    set signatureParts [list $method ${Content-MD5} ${Content-Type} $Date]

    if {[llength ${x-amzHeaders}]} {
        lappend signatureParts [join ${x-amzHeaders} "\n"]
    }

    lappend signatureParts $resource 
    ::nss3::setParam signatureParts $signatureParts

    set signatureString [join $signatureParts "\n"]
    set signature [::sha1::hmac [::nss3::getConfig privateKey] $signatureString]
    set signature [binary format H* $signature]
    set signature [string trim [::base64::encode $signature]]

    return "AWS [::nss3::getConfig publicKey]:${signature}"
}

proc ::nss3::createRequest {action bucket object data contentType} {
    switch -exact $action {
        createBucket {
            ::nss3::setParam method PUT
            ::nss3::setParam resource /${bucket}
        }
        writeObject {
            ::nss3::setParam method PUT
            ::nss3::setParam body $data
            ::nss3::setParam resource /${bucket}/${object}
            ::nss3::setHeader Content-Type $contentType
            ::nss3::setHeader x-amz-meta-title $object
            ::nss3::setHeader Content-MD5 [::base64::encode [::md5::md5 $data]] 
            ::nss3::setHeader Content-Length [string length $data]    
        }
        getObject {
            set resource [list ${bucket}]
            if {[string length ${object}]} {
                lappend resource ${object}
            }
            ::nss3::setParam method GET
            ::nss3::setParam resource /[join $resource "/"]
        }
        delete {
            set resource [list $bucket]
            if {[string length $object]} {
                lappend resource $object
            }
            ::nss3::setParam method DELETE
            ::nss3::setParam resource /[join $resource "/"]
        }
        deleteBucket {
            ::nss3::setParam method DELETE
            ::nss3::setParam resource /${bucket}
        }
        attributes {
            set resource [list $bucket]
            if {[string length $object]} {
                lappend resource $object
            }
            ::nss3::setParam method HEAD
            ::nss3::setParam resource /[join $resource "/"]
        }
    }

    set dateFormat "%a, %d %b %Y %T %Z"
    set timestamp [clock format [clock seconds] -format $dateFormat]

    ::nss3::setHeader Date $timestamp
    ::nss3::setHeader Authorization [buildAuthHeader]
}

proc ::nss3::debug {} {
    if {![string length [set v [::nss3::getConfig debug]]] || \
        ![string is int $v]} {
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

proc ::nss3::logRequest {} {
    global request
    set output [list]

    foreach key [lsort [array names request]] {
        set value $request(${key})
        ns_log debug "nss3: ${key}: ${value}"
    }
}

proc ::nss3::clearRequest {} {
    global request
    array unset request
}

proc ::nss3::parseArgs {arrayName argList} {
    upvar $arrayName argsArr

    set i 0
    # set args [split $argList]
    set args $argList

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
