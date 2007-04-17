# ::nsfile::write --
#
#     This file implements the Tcl code for manipulating local files in a
#     thread-safe manner.
#
#     Tmp files are used to ensure atomic operations without
#     mutex locks which would increase lock contention. There will always
#     be a race-condition between threads. But the use of mutexes,
#     or in this case tmp files, ensures thread safety.
# 
# $Id:$

package require fileutil
package provide nsfile 1.0

namespace eval nsfile {
}

# ::nsfile::write --
#
#     Writes $contents to $file. If $file does not exist it will be created. 
#     If $file does exist it will be overwritten.
# 
# Arguments:
#     file: the name of the file to write.
#     contents: the contents of the file.
#
# Results:
#     Writes $contents to a tmp file then does an atomic rename to $file.
#
#     1: Success
#     error: Failure

proc ::nsfile::write {file contents} {
    set tmpFile [fileutil::tempfile]
    fileutil::writeFile $tmpFile
    file rename -force $tmpFile $file
    return 1
}

# ::nsfile::append --
#
#     Appends $contents to $file. If $file does not exist it will be created.
#     
# Arguments:
#     file: the name of the file to write.   
#     contents: the contents of the file.
#
# Results:
#     Reads $file into a tmp file, appends it with $content, then does an
#     atomic rename to $file.
#
#     1: Success
#     error: Failure

proc ::nsfile::append {file contents} {
    set tmpFile [fileutil::tempfile]
    file copy -force $file $tmpFile
    fileutil::appendToFile $tmpFile $contents
    file rename -force $tmpFile $file
    return 1
}

# ::nsfile::read --
# 
#    Returns the contents of $file.
# 
# Arguments:
#     file. The name of the file to read.
#
# Results:
#     Returns the contents of $file, or thows an error.

proc ::nsfile::read {file} {
    return [fileutil::cat $file]
}

# ::nsfile::copy --
#
#     Copys $file to $newFile. If $newFile does not exist it will be 
#     created. If $newFile does exist it will be overwritten.
#
# Arguments:
#     file. The name of the file to copy.
#     newFile. The name of new file.
#
# Results:
#     $file is copied to $newFile. A 1 is retunred on success.

proc ::nsfile::copy {file newFile} {
    set tmpFile [fileutil::tempfile]
    file copy -force $file $tmpFile
    file rename -force $tmpFile $newFile
    return 1
}

proc ::nsfile::rename {file newFile} {
    file rename -force $file $newFile 
    return 1
}

proc ::nsfile::delete {file} {
    file delete -force $file
    return 1
}
