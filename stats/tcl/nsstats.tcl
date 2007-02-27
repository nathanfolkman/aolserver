ns_ictl package require nsstats

set path "ns/server/nsstats"

set enabled [ns_config -bool $path enabled "true"]
set user [ns_config $path user "aolserver"]
set password [ns_config $path password "stats"]

nsstats::enable $enabled
nsstats::setLogin $user $password

nsstats::addStat driver "Driver"
nsstats::addStat threads "Threads"

#
# Driver
#

nsstats::addColumn "driver" "name" "Name" "string"
nsstats::addColumn "driver" "time" "Time" "date"
nsstats::addColumn "driver" "spins" "Spins" "int"
nsstats::addColumn "driver" "accepts" "Accepts" "int"
nsstats::addColumn "driver" "queued" "Queued" "int"
nsstats::addColumn "driver" "reads" "Reads" "int"
nsstats::addColumn "driver" "dropped" "Dropped" "int"
nsstats::addColumn "driver" "overflow" "Overflows" "int"
nsstats::addColumn "driver" "timeout" "Timeouts" "int"

nsstats::setColumns "driver" [list "name" "time" "spins" "accepts" "queued" "reads" "dropped" "overflow" "timeout"]