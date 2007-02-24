ns_ictl package require nsstats

set path "ns/server/nsstats"

set enabled [ns_config -bool $path enabled "true"]
set user [ns_config $path user "aolserver"]
set password [ns_config $path password "stats"]

nsstats::enable $enabled
nsstats::setLogin $user $password

nsstats::addStat threads "Threads"
nsstats::addStat driver "Driver"
