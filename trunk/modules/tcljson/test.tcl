#load libtcljson.so

set a [json.newArray]

set s_1 [json.newString "one"]
set s_2 [json.newString "two"]
set s_3 [json.newString "three"]

json.arrayAddObject $a $s_1
json.arrayAddObject $a $s_2
json.arrayAddObject $a $s_3

set o [json.newObject]

set i [json.newInt 100]
set d [json.newDouble 100000]
set s [json.newString "Hello World!"]
set b [json.newBoolean 0]

json.objectAddObject $o "int" $i
json.objectAddObject $o "double" $d
json.objectAddObject $o "string" $s
json.objectAddObject $o "boolean" $b
json.objectAddObject $o "array" $a

puts [json.objectToString $o]

set string "\{ \"int\": 100, \"double\": 100000.000000, \"string\": \"Hello World!\", \"boolean\": false, \"array\": \[ \"one\", \"two\", \"three\" \] \}"

#set o_2 [json.stringToObject $string]

#puts [json.objectToString $o_2]
