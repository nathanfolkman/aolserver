package require sha1
package require md5
package require base64

package provide aws 0.1

namespace eval ::aws {
    variable config
    set config(debug) 1
    set config(timeout) 2
}

proc aws::setConfig {key value} {
    variable config
    set config(${key}) $value
}

proc aws::getConfig {key} {
    variable config
    return $config(${key})
}

proc aws::createRequest {} {
    set uid 0
    set token aws${uid}

    while {[info exists [namespace current]::${token}]} {
        set token aws[incr uid] 
    }

    variable $token
    set ${token}(param.created) [ns_time]

    return $token
}

proc aws::validateToken {token} {
    variable $token

    if {![info exists ${token}]} {
        error "Invalid token \"${token}\"."
    }

    return 
}

proc aws::setValue {token namespace key value} {
    aws::validateToken $token
    variable $token
    set ${token}(${namespace}.${key}) $value
}

proc aws::setValuesFromAgf {token namespace agf} {
    aws::validateToken $token
    variable $token

    foreach {key value} $agf {
        aws::setValue $token $namespace $key $value
    }

    return
}

proc aws::getValue {token namespace key} {
    aws::validateToken $token
    variable $token

    if {![info exists ${token}(${namespace}.${key})]} {
        return ""
    }

    return [subst $${token}(${namespace}.${key})]
}

proc aws::setParam {token param value} {
    return [aws::setValue $token param $param $value]
}

proc aws::setParamsFromAgf {token agfList} {
    return [aws::setValuesFromAgf $token param $agfList]
}

proc aws::getParam {token param} {
    return [aws::getValue $token param $param]
}

proc aws::setHeader {token header value} {
    return [aws::setValue $token header $header $value]
}

proc aws::getHeader {token header} {
    return [aws::getValue $token header $header]
}

proc aws::names {token {pattern ""}} {
    aws::validateToken $token
    variable $token

    lappend command array names $token 

    if {[string length $pattern]} {
        lappend command $pattern
    }

    return [eval $command]
}

proc aws::headerNames {token {pattern "*"}} {
    set pattern header.${pattern}
    set result [list]

    foreach name [aws::names $token $pattern] {
        lappend result [lindex [split $name "."] 1]
    }

    return $result 
}

proc aws::paramNames {token {pattern "*"}} {
    set pattern param.${pattern}
    set result [list]

    foreach name [aws::names $token $pattern] {
        lappend result [lindex [split $name "."] 1]
    }

    return $result
}

proc aws::logRequest {token} {
    aws::validateToken $token
    variable $token

    foreach name [lsort [array names $token]] {
        set namespace [lindex [set parts [split $name "."]] 0]
        set key [lindex $parts 1]
        set value [aws::getValue $token $namespace $key]
        ns_log debug "aws: ${token}: ${namespace}: ${key}: ${value}"
    }
}

proc aws::queueCurl {token} {
    aws::validateToken $token
    variable $token
    
    set outputHeaders "Expect:"
    
    foreach name [aws::headerNames $token] {
        lappend outputHeaders "$name: [aws::getHeader $token $name]"
    }
    
    set curl [::curl::init]
    
    if {[string length [aws::getHeader $token Content-Length]]} {
        $curl configure -postfields [aws::getParam $token data]
        $curl configure -postfieldssize [string length [aws::getParam $token data]]
    }
   
    $curl configure -customrequest [aws::getParam $token method]
    $curl configure -httpheader $outputHeaders
    $curl configure -headervar headers
    $curl configure -bodyvar body
    $curl configure -stderr stderr
    $curl configure -verbose 3
    $curl configure -url [aws::getParam $token host][aws::getParam $token resource]
    
    set result [$curl perform]
    
    ns_log notice $body
    
    $curl cleanup
    return $result
}

proc aws::buildSignature {token} {
    aws::validateToken $token
    variable $token

    set x-amzHeaders [list]

    foreach header [lsort [aws::headerNames $token x-amz-*]] {
        set value [aws::getHeader $token $header]
        lappend x-amzHeaders "${header}:${value}"
    }

    lappend signatureParts [aws::getParam $token method]
    lappend signatureParts [aws::getHeader $token Content-MD5]
    lappend signatureParts [aws::getHeader $token Content-Type] 
    lappend signatureParts [aws::getHeader $token Date]

    if {[llength ${x-amzHeaders}]} {
        lappend signatureParts [join ${x-amzHeaders} "\n"]
    }

    lappend signatureParts [aws::getParam $token resource]

    aws::setParam $token signatureParts [string map {\n " "} $signatureParts]

    set signatureString [join $signatureParts "\n"]
    set signature [::sha1::hmac [aws::getConfig privateKey] $signatureString]
    set signature [binary format H* $signature]
    set signature [string trim [::base64::encode $signature]]

    aws::setParam $token signature $signature

    return $signature
}

proc aws::queue {token} {
    foreach param [list method host resource] {
        if {![string length [aws::getParam $token $param]]} {
            error "Missing required param: ${param}"
        }
    }

    variable $token

    if {![string match /* [aws::getParam $token resource]]} {
        aws::setParam $token resource "/[aws::getParam $token resource]"
    }

    if {[set dataLength [string length [aws::getParam $token data]]]} {
        set dataMD5 [base64::encode [md5::md5 [aws::getParam $token data]]]
        aws::setHeader $token Content-MD5 $dataMD5
        aws::setHeader $token Content-Length $dataLength
    }

    set dateFormat "%a, %d %b %Y %T %Z"
    set timestamp [clock format [clock seconds] -format $dateFormat]
    aws::setHeader $token Date $timestamp

    set authHeader "AWS [aws::getConfig publicKey]:[aws::buildSignature $token]"
    aws::setHeader $token Authorization $authHeader

    if {[string match 1 [aws::getConfig debug]]} {
        aws::logRequest $token
    }

    # I might swap out ns_http for another transport
    set jobToken [aws::queueNsHttp $token]
    #set jobToken [aws::queueCurl $token]
    

    aws::destroyRequest $token

    return $jobToken
}

proc aws::destroyRequest {token} {
    aws::validateToken $token   
    variable $token
    array unset $token
}

proc aws::queueNsHttp {token} {
    aws::validateToken $token
    variable $token 
    
    set requestHeaders [ns_set create]

    foreach name [aws::headerNames $token] {
        set value [aws::getHeader $token $name]
        ns_set put $requestHeaders $name $value
    }

    lappend command ns_http queue -method [aws::getParam $token method]
    lappend command -headers $requestHeaders

    if {[string length [aws::getHeader $token Content-Length]]} {
        lappend command -body [aws::getParam $token data]
    }

    if {[string is int -strict [aws::getParam $token timeout]]} {
        lappend command -timeout [aws::getParam $token timeout]
    } elseif {[string is int -strict [aws::getConfig timeout]]} {
        lappend command -timeout [aws::getConfig timeout]
    }

    lappend command [aws::getParam $token host][aws::getParam $token resource]

    if {[string match 1 [aws::getConfig debug]]} {
        ns_log debug "aws: ${token}: ${command}"
        ns_set print $requestHeaders
    }

    return [eval $command]
}

proc aws::wait {jobId resultVarName statusVarName headerSetId} {
    upvar $resultVarName result
    upvar $statusVarName status

    # I might swap out ns_http for another trasport
    return [aws::waitNsHttp $jobId result status $headerSetId]
}

proc aws::waitNsHttp {httpId resultVarName statusVarName headerSetId} {
    upvar $resultVarName result
    upvar $statusVarName status

    lappend command ns_http wait -result result -status status 
    lappend command -headers $headerSetId $httpId

    return [eval $command]
}
