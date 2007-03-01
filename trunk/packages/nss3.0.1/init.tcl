package require sha1
package require md5
package require base64

package provide nss3 0.1

namespace eval ::nss3:: {
    variable config
    set config(host) http://s3.amazonaws.com
    set config(debug) 1

    namespace export queue
    namespace export wait
}
