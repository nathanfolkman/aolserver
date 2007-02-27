namespace eval nsstats {
    namespace export enable
    
    variable Thread
    variable Sched
	variable Columns
    
    set Thread(0)   "NS_OK"
    set Thread(-1)  "NS_ERROR"
    set Thread(-2)  "NS_TIMEOUT"
    set Thread(200) "NS_THREAD_MAXTLS"
    set Thread(1)   "NS_THREAD_DETACHED"
    set Thread(2)   "NS_THREAD_JOINED"
    set Thread(4)   "NS_THREAD_EXITED"
    set Thread(32)  "NS_THREAD_NAMESIZE"
    
    set Sched(1)    "THREAD"
    set Sched(2)    "ONCE"
    set Sched(4)    "DAILY"
    set Sched(8)    "WEEKLY"
    set Sched(16)   "PAUSED"
    set Sched(32)   "RUNNING"
    
    proc getFlagValues {type flag} {
        set array [string totitle $type]
        
        variable $array
        
        if {![info exists $array]} {
            return ""
        }
        
        if {$flag <= 0} {
            if {[catch {
                set value [eval set value [subst $${array}($flag)]]
            }]} {
                set value ""
            }
            
            return $value
        }
        
        set values ""
        set keys [array names $array]
        
        foreach key $keys {
            if {$key < 0} {
                continue
            }
            if {[expr $flag & $key]} {
                lappend values [eval set value [subst $${array}($key)]]
            }
        }
        
        return $values
    }
 
    proc enable {{bool ""}} {
        if {![nsv_exists nsstats enabled]} {
            nsv_set nsstats enabled 1
        }
        
        set enabled [nsv_get nsstats enabled]
        
        if {[string length $bool]} {
            set enabled $bool
            nsv_set nsstats enabled $enabled
        }
        
        return $enabled
    }
    
    proc setLogin {user password} {
        nsv_set nsstats user $user
        nsv_set nsstats password $password
        
        return 1
    }
    
    proc authenticate {user password} {
        set u [nsv_get nsstats user]
        set p [nsv_get nsstats password]
        
        if {![string match $user $u] && ![string match $password $p]} {
            return 0
        } 
        
        return 1
    }
    
    proc addStat {name description} {
        variable Stats
        
        return [set Stats($name) $description]
    }

	proc setColumns {stat colNames} {
		variable Columns
		
		return [set Columns($stat) $colNames]
	}
	
	proc addColumn {stat colName description type} {
		variable Columns
		
		return [set Columns($stat,$colName) [list $colName $description $type]]
	}
	
	proc getColumns {stat} {
		variable Columns
		
		if {![info exists Columns($stat)]} {
			return ""
		}
		
		return $Columns($stat)
	}
	
	proc getColumn {stat colName} {
		variable Columns

		if {![info exists Columns($stat,$colName)]} {
			return ""
		}
		
		return $Columns($stat,$colName)
	}
    
    proc getStatDescription {name} {
        variable Stats
        
        if {![info exists Stats($name)]} {
            return ""
        }
        
        return $Stats($name)
    }
    
    proc getStats {} {
        variable Stats
        
        return [lsort [array names Stats]]
    }
    
    proc statExists {name} {
        variable Stats
        
        return [info exists Stats($name)]
    }
    
    proc formatSeconds {seconds} {
        if {$seconds < 60} {
            return "${seconds} (s)"
        }

        if {$seconds < 3600} {
            set mins [expr $seconds/60]
            set secs [expr $seconds - ($mins * 60)]

            return "${mins}:${secs} (m:s)"
        }

        set hours [expr $seconds/3600]
        set mins [expr ($seconds - ($hours * 3600))/60]
        set secs [expr $seconds - (($hours * 3600) + ($mins * 60))]

        return "${hours}:${mins}:${secs} (h:m:s)"
    }
}

package provide nsstats 1.0

