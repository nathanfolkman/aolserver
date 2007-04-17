package require aws

package provide s3 0.1

namespace eval ::s3:: {
    variable config
    set config(host) http://s3.amazonaws.com
    set config(debug) 1
    set config(timeout) 2

    namespace import ::aws::*
}

proc ::s3::setConfig {key value} {
    variable config
    set config(${key}) $value
}

proc ::s3::getConfig {key} {
    variable config
    return $config(${key})
}

proc ::s3::queue {token} {
    lappend validActions createBucket listBucket getObject
    lappend validActions writeObject delete headers

    if {[string match -actions $token]} {
        return $validActions
    }

    foreach param [list action bucket] {
        if {![string length [s3::getParam $token $param]]} {
            error "Missing required param: ${param}"
        }
    }

    if {[lsearch -exact $validActions [s3::getParam $token action]] == -1} {
        set msg "Invalid action \"[s3::getParam $token action]\". Should be "
        append msg "${validActions}."
        error $msg
    }

    s3::buildAwsRequest $token
    return [::aws::queue $token] 
}

proc ::s3::buildAwsRequest {token} {
    s3::setParam $token host [s3::getConfig host]

    # Use the request param timout, or the S3 default timeout
    # or the aws default timeout, or do not set a timeout.
    # If no timout is set the transport's default timeout 
    # will be used. E.g., ns_http with no timeout flag
    
    if {![string length [s3::getParam $token timeout]]} {
        if {[string length [s3::getConfig timeout]]} {
            s3::setParam $token timout [::s3::getConfig timeout]
        } else {
            s3::setParam $token timout [::aws::getConfig timout]
        }
    }

    switch -exact -- [s3::getParam $token action] {
        createBucket {
            s3::setParam $token method PUT
            s3::setParam $token resource [s3::getParam $token bucket]
        }
        listBucket {
            s3::setParam $token method GET
            s3::setParam $token resource [s3::getParam $token bucket]
        }
        writeObject {
            if {![string length [s3::getParam $token object]]} {
                error "Missing required param \"object\"."
            }
            s3::setParam $token method PUT
            lappend resourceParts [s3::getParam $token bucket]
            lappend resourceParts [s3::getParam $token object]
            s3::setParam $token resource [join $resourceParts "/"]
        }
        getObject {
            if {![string length [s3::getParam $token object]]} {
                error "Missing required param \"object\"."
            }
            s3::setParam $token method GET
            lappend resourceParts [s3::getParam $token bucket]
            lappend resourceParts [s3::getParam $token object]
            s3::setParam $token resource [join $resourceParts "/"]
        }
        delete {
            s3::setParam $token method DELETE
            lappend resourceParts [s3::getParam $token bucket]
            lappend resourceParts [s3::getParam $token object]
            s3::setParam $token resource [join $resourceParts "/"]
        }
        head {
            s3::setParam $token method HEAD
             ppend resourceParts [s3::getParam $token bucket]
            lappend resourceParts [s3::getParam $token object]
            s3::setParam $token resource [join $resourceParts "/"]
        }
    }
}

proc ::s3::wait {jobId  resultVar statusVar headerSetId} {
    upvar $resultVar result
    upvar $statusVar status

    return [::aws::wait $jobId result status $headerSetId]
}
