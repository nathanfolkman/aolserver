#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "tcl.h"
#include "json.h"

extern int Tcljson_Init(Tcl_Interp *interp);
extern int Tcljson_JsonObjToTclObj(struct json_object *joPtr, Tcl_Obj **objPtr);
extern int Tcljson_JsonObjFromTclObj(Tcl_Interp *interp, Tcl_Obj *objPtr, struct json_object **joPtrPtr);
extern int Tcljson_TclObjIsJsonObj(Tcl_Obj *objPtr);

static Tcl_ObjCmdProc TcljsonNewObjectObjCmd;
static Tcl_ObjCmdProc TcljsonGetObjectObjCmd;
static Tcl_ObjCmdProc TcljsonGetArrayObjCmd;
static Tcl_ObjCmdProc TcljsonAddObjectObjCmd;
static Tcl_ObjCmdProc TcljsonObjectToStringObjCmd;
static Tcl_ObjCmdProc TcljsonStringToObjectObjCmd;

static void TcljsonObjFree(Tcl_Obj *objPtr);
static void TcljsonObjUpdateStr(Tcl_Obj *objPtr);

typedef struct TclJsonObject {
    struct json_object *joPtr;
} TclJsonObject;

Tcl_ObjType tclJsonObjectType = {
    "JSON_OBJECT",     
    TcljsonObjFree,     
    NULL,               
    TcljsonObjUpdateStr,   
    NULL               
};

static void 
TcljsonObjFree(Tcl_Obj *objPtr)
{
    TclJsonObject *tsPtr = (TclJsonObject *) objPtr->internalRep.otherValuePtr;
    Tcl_Free((char *)tsPtr);
}

static void
TcljsonObjUpdateStr(Tcl_Obj *objPtr)
{
    static CONST char *jsonTypeArr[] = {
        "NULL",
        "BOOLEAN",
        "DOUBLE",
        "INT",
        "OBJECT",
        "ARRAY",
        "STRING"
    };
    int len;
    enum json_type type;
    char buf[32];
    TclJsonObject *tjPtr;

    tjPtr = (TclJsonObject *) objPtr->internalRep.otherValuePtr;
    type = json_object_get_type(tjPtr->joPtr);
    snprintf(buf, 31, "JSON_OBJECT:%s(%p)", jsonTypeArr[type], tjPtr->joPtr);

    len = strlen(buf);
    objPtr->bytes = ckalloc(len + 1);
    strcpy(objPtr->bytes, buf);
    objPtr->length = strlen(objPtr->bytes);
}

int
Tcljson_JsonObjToTclObj(struct json_object *joPtr, Tcl_Obj **objPtr) 
{
    TclJsonObject *tjPtr;

    *objPtr = NULL;
    tjPtr = (TclJsonObject *) Tcl_Alloc(sizeof(TclJsonObject));
    tjPtr->joPtr = joPtr;

    *objPtr = Tcl_NewObj();
    (*objPtr)->internalRep.otherValuePtr = (VOID *) tjPtr;
    (*objPtr)->typePtr = &tclJsonObjectType;
    Tcl_InvalidateStringRep(*objPtr);

    return TCL_OK;
}

int
Tcljson_JsonObjFromTclObj(Tcl_Interp *interp, Tcl_Obj *objPtr, struct json_object **joPtrPtr)
{
    TclJsonObject *tjPtr;
    
    if (objPtr->typePtr == NULL) {
        if (interp != NULL) {
            Tcl_SetResult(interp, "invalid json object", TCL_STATIC);
        }
        return TCL_ERROR;
    }

    if (Tcljson_TclObjIsJsonObj(objPtr) != 1) {
        if (Tcl_ConvertToType(interp, objPtr, &tclJsonObjectType) != TCL_OK) {
            if (interp != NULL) {
                Tcl_SetResult(interp, "invalid json object", TCL_STATIC);
            }
            return TCL_ERROR;
        }
    }

    tjPtr = (TclJsonObject *) objPtr->internalRep.otherValuePtr;
    *joPtrPtr = tjPtr->joPtr;

    return TCL_OK;
}

int
Tcljson_TclObjIsJsonObj(Tcl_Obj *objPtr)
{
    return (objPtr->typePtr == &tclJsonObjectType);
}

int
Tcljson_Init(Tcl_Interp *interp)
{
    Tcl_RegisterObjType(&tclJsonObjectType);

    Tcl_CreateObjCommand(interp, "json.newObject", TcljsonNewObjectObjCmd, (ClientData) 'o', NULL);
    Tcl_CreateObjCommand(interp, "json.putObject", TcljsonNewObjectObjCmd, (ClientData) 'p', NULL);
    Tcl_CreateObjCommand(interp, "json.newInt", TcljsonNewObjectObjCmd, (ClientData) 'i', NULL);
    Tcl_CreateObjCommand(interp, "json.newString", TcljsonNewObjectObjCmd, (ClientData) 's', NULL);
    Tcl_CreateObjCommand(interp, "json.newDouble", TcljsonNewObjectObjCmd, (ClientData) 'd', NULL);
    Tcl_CreateObjCommand(interp, "json.newBoolean", TcljsonNewObjectObjCmd, (ClientData) 'b', NULL);
    Tcl_CreateObjCommand(interp, "json.newArray", TcljsonNewObjectObjCmd, (ClientData) 'a', NULL);
    Tcl_CreateObjCommand(interp, "json.getObject", TcljsonGetObjectObjCmd, (ClientData) NULL, NULL);
    Tcl_CreateObjCommand(interp, "json.getArray", TcljsonGetArrayObjCmd, (ClientData) NULL, NULL);
    Tcl_CreateObjCommand(interp, "json.objectAddObject", TcljsonAddObjectObjCmd, (ClientData) 'o', NULL);
    Tcl_CreateObjCommand(interp, "json.arrayAddObject", TcljsonAddObjectObjCmd, (ClientData) 'a', NULL);
    Tcl_CreateObjCommand(interp, "json.objectToString", TcljsonObjectToStringObjCmd, NULL, NULL);
    Tcl_CreateObjCommand(interp, "json.stringToObject", TcljsonStringToObjectObjCmd, NULL, NULL);

    return TCL_OK;
}

static int
TcljsonNewObjectObjCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    struct json_object *jsonPtr = NULL;
    Tcl_Obj *objPtr;
    char *stringVal;
    double doubleVal;  
    boolean boolVal;
    int intVal;
    int type = (int) clientData;
    int len;

    switch (type) {
    case 'o':
        jsonPtr = json_object_new_object();

        break;

    case 'p':
        if (objc != 2) {
            Tcl_WrongNumArgs(interp, 1, objv, "object");
            return TCL_ERROR;
        }
        if (Tcljson_JsonObjFromTclObj(interp, objv[1], &jsonPtr) != TCL_OK) {
            return TCL_ERROR;
        }
        objPtr = objv[1];
        json_object_put(jsonPtr);

        break;
    case 'i':
        if (objc != 2) {
            Tcl_WrongNumArgs(interp, 1, objv, "int");
            return TCL_ERROR;
        }
        if (Tcl_GetIntFromObj(interp, objv[1], &intVal) != TCL_OK) {
            return TCL_ERROR;
        }

        jsonPtr = json_object_new_int(intVal);

        break;

    case 's':
        if (objc != 2) {
            Tcl_WrongNumArgs(interp, 1, objv, "string");
            return TCL_ERROR;
        }

        stringVal = Tcl_GetStringFromObj(objv[1], &len);  

        jsonPtr = json_object_new_string(stringVal);

        break;

    case 'd':
        if (objc != 2) {
            Tcl_WrongNumArgs(interp, 1, objv, "double");
            return TCL_ERROR;
        }
        if (Tcl_GetDoubleFromObj(interp, objv[1], &doubleVal) != TCL_OK) {
            return TCL_ERROR;
        }

        jsonPtr = json_object_new_double(doubleVal);

        break;

    case 'b':
        if (objc != 2) {
            Tcl_WrongNumArgs(interp, 1, objv, "boolean");
            return TCL_ERROR;
        }
        if (Tcl_GetBooleanFromObj(interp, objv[1], &boolVal) != TCL_OK) {
            return TCL_ERROR;
        }
 
        jsonPtr = json_object_new_boolean(boolVal);

        break;

    case 'a':
        jsonPtr = json_object_new_array();
   
        break;
    }

    if (Tcljson_JsonObjToTclObj(jsonPtr, &objPtr) != TCL_OK) {
        Tcl_SetResult(interp, "failed to convert json object to tcl object.", TCL_STATIC);
        return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, objPtr);

    return TCL_OK;
}

static int
TcljsonGetArrayObjCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    struct json_object *jsonPtr = NULL;
    struct json_object *jsonPtr2 = NULL;
    enum json_type type;
    Tcl_Obj *objPtr;
    Tcl_Obj *objPtr2;
    int i;
    
    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "array");
        return TCL_ERROR;
    }
    
    if (Tcljson_JsonObjFromTclObj(interp, objv[1], &jsonPtr) != TCL_OK) {
        return TCL_ERROR;
    }
    
    objPtr = Tcl_NewListObj(0, NULL);
    
    for(i=0; i < json_object_array_length(jsonPtr); i++) {
        jsonPtr2 = json_object_array_get_idx(jsonPtr, i);
        type = json_object_get_type(jsonPtr2);
        
        if (type == json_type_array) {
            if (Tcljson_JsonObjToTclObj(jsonPtr2, &objPtr2) != TCL_OK) {
                Tcl_SetResult(interp, "failed to convert json object to tcl object.", TCL_STATIC);
                return TCL_ERROR;
            }
        } else {
            objPtr2 = Tcl_NewStringObj(json_object_to_json_string(jsonPtr2), -1);
        }
        
        Tcl_ListObjAppendElement(interp, objPtr, objPtr2);
    }
    
    Tcl_SetObjResult(interp, objPtr);

    return TCL_OK;
}

static int
TcljsonGetObjectObjCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    struct json_object *jsonPtr = NULL;
    enum json_type type;
    Tcl_Obj *objPtr;
    char *key;
    int len, found;
   
    if (objc != 3) {
        Tcl_WrongNumArgs(interp, 1, objv, "object key");
        return TCL_ERROR;
    }
    
    if (Tcljson_JsonObjFromTclObj(interp, objv[1], &jsonPtr) != TCL_OK) {
        return TCL_ERROR;
    }
   
    key = Tcl_GetStringFromObj(objv[2], &len);
    found = 0;
    json_object_object_foreach(jsonPtr, key2, value2) {
        if (strcmp(key, key2) == 0) {
            type = json_object_get_type(value2);
            found = 1;
            
            if (type == json_type_array) {
                if (Tcljson_JsonObjToTclObj(value2, &objPtr) != TCL_OK) {
                    Tcl_SetResult(interp, "failed to convert json object to tcl object.", TCL_STATIC);
                    return TCL_ERROR;
                }
            } else {
                objPtr = Tcl_NewStringObj(json_object_to_json_string(value2), -1);
            }
            
            break;
        }
    }
    
    if (!found) {
        Tcl_SetResult(interp, "invalid key", TCL_STATIC);
        return TCL_ERROR;
    }
  
    Tcl_SetObjResult(interp, objPtr);

    return TCL_OK;
}

static int
TcljsonAddObjectObjCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    struct json_object *jsonObj_1;
    struct json_object *jsonObj_2;
    char *key;
    int type = (int) clientData;
    int len;

    switch (type) {
    case 'o':
        if (objc != 4) {
            Tcl_WrongNumArgs(interp, 1, objv, "object key object");
            return TCL_ERROR;
        }
        if (Tcljson_JsonObjFromTclObj(interp, objv[1], &jsonObj_1) != TCL_OK
            || Tcljson_JsonObjFromTclObj(interp, objv[3], &jsonObj_2) != TCL_OK) {
            return TCL_ERROR;
        }

        key = Tcl_GetStringFromObj(objv[2], &len);

        break;

    case 'a':
        if (objc != 3) {
            Tcl_WrongNumArgs(interp, 1, objv, "array object");
            return TCL_ERROR;
        }
        if (Tcljson_JsonObjFromTclObj(interp, objv[1], &jsonObj_1) != TCL_OK
            || Tcljson_JsonObjFromTclObj(interp, objv[2], &jsonObj_2) != TCL_OK) {
            return TCL_ERROR;
        }

        break;
    }

    switch (type) {
    case 'o':
        json_object_object_add(jsonObj_1, key, jsonObj_2);
       
        break;
   
    case 'a':
        json_object_array_add(jsonObj_1, jsonObj_2); 

        break;
    }

    return TCL_OK;
}

static int
TcljsonObjectToStringObjCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    struct json_object *jsonObj;
    char *string;
    Tcl_Obj *objPtr;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "object");
        return TCL_ERROR;
    }
    if (Tcljson_JsonObjFromTclObj(interp, objv[1], &jsonObj) != TCL_OK) {
        return TCL_ERROR;
    }

    string = json_object_to_json_string(jsonObj);

    objPtr = Tcl_NewStringObj(string, -1);
    Tcl_SetObjResult(interp, objPtr);

    return TCL_OK;
}

static int
TcljsonStringToObjectObjCmd(ClientData clientData, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
    struct json_object *jsonPtr = NULL;
    char *string;
    int len;
    Tcl_Obj *objPtr;

    if (objc != 2) {
        Tcl_WrongNumArgs(interp, 1, objv, "string");
        return TCL_ERROR;
    }

    string = Tcl_GetStringFromObj(objv[1], &len);
    jsonPtr = json_tokener_parse(string);

	if (jsonPtr == 0xfffffffffffffffc) {
		Tcl_SetResult(interp, "could not parse json string.", TCL_STATIC);
		return TCL_ERROR;
	}

	if (Tcljson_JsonObjToTclObj(jsonPtr, &objPtr) != TCL_OK) {
        Tcl_SetResult(interp, "failed to convert json object to tcl object.", TCL_STATIC);
        return TCL_ERROR;
    }

    Tcl_SetObjResult(interp, objPtr);

    return TCL_OK;
}