ns_ictl package require nsstats

set path "ns/server/nsstats"

set enabled [ns_config -bool $path enabled "true"]
set user [ns_config $path user "aolserver"]
set password [ns_config $path password "stats"]

nsstats::enable $enabled
nsstats::setLogin $user $password

#
# Driver
#

nsstats::addStat driver "Driver"

nsstats::addColumn "driver" "name" "Name" "string"
nsstats::addColumn "driver" "time" "Time" "date"
nsstats::addColumn "driver" "spins" "Spins" "number"
nsstats::addColumn "driver" "accepts" "Accepts" "number"
nsstats::addColumn "driver" "queued" "Queued" "number"
nsstats::addColumn "driver" "reads" "Reads" "number"
nsstats::addColumn "driver" "dropped" "Dropped" "number"
nsstats::addColumn "driver" "overflow" "Overflows" "number"
nsstats::addColumn "driver" "timeout" "Timeouts" "number"

#
# Threads
#

nsstats::addStat threads "Threads"

nsstats::addColumn "threads" "name" "Name" "string"
nsstats::addColumn "threads" "parent" "Parent" "string"
nsstats::addColumn "threads" "tid" "Thread Id" "number"
nsstats::addColumn "threads" "flags" "Flags" "string"
nsstats::addColumn "threads" "ctime" "Created" "date"
nsstats::addColumn "threads" "proc" "Proc" "string"
nsstats::addColumn "threads" "args" "Args" "string"
nsstats::addColumn "threads" "connid" "Conn Id" "number"
nsstats::addColumn "threads" "peer" "Peer" "string"
nsstats::addColumn "threads" "state" "State" "string"
nsstats::addColumn "threads" "elapsed" "Elapsed" "number"
nsstats::addColumn "threads" "sent" "Sent" "number"
nsstats::addColumn "threads" "method" "Method" "string"
nsstats::addColumn "threads" "url" "URL" "string"

