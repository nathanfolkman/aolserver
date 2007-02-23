/*
 * The contents of this file are subject to the AOLserver Public License
 * Version 1.1 (the "License"); you may not use this file except in
 * compliance with the License. You may obtain a copy of the License at
 * http://aolserver.com/.
 *
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
 * the License for the specific language governing rights and limitations
 * under the License.
 *
 * The Original Code is AOLserver Code and related documentation
 * distributed by AOL.
 *
 * The Initial Developer of the Original Code is America Online,
 * Inc. Portions created by AOL are Copyright (C) 1999 America Online,
 * Inc. All Rights Reserved.
 *
 * Alternatively, the contents of this file may be used under the terms
 * of the GNU General Public License (the "GPL"), in which case the
 * provisions of GPL are applicable instead of those above.  If you wish
 * to allow use of your version of this file only under the terms of the
 * GPL and not to allow others to use your version of this file under the
 * License, indicate your decision by deleting the provisions above and
 * replace them with the notice and other provisions required by the GPL.
 * If you do not delete the provisions above, a recipient may use your
 * version of this file under either the License or the GPL.
 */

#include "ns.h"
#include "nsjs.h"
#include "jsapi.h"

typedef struct {
	JSRuntime *runtime;
	JSContext *context;
	JSObject *object;
} jsEnv;

static Ns_Tls tls;
static Ns_TlsCleanup JsCleanup;

static Tcl_ObjCmdProc JsEvalObjCmd;

static int JsInit(Tcl_Interp *interp, void *ignored);
void JsLogError(JSContext *cx, const char *message, JSErrorReport *report);

int
Ns_ModuleInit(char *server, char *module)
{
	Ns_TclRegisterTrace(server, JsInit, NULL, NS_TCL_TRACE_CREATE);
	
	return NS_OK;
}

static int
JsInit(Tcl_Interp *interp, void *arg) 
{
	jsEnv *jsEnvPtr;
	
	Ns_TlsAlloc(&tls, JsCleanup);
	
	jsEnvPtr = ns_calloc(1, sizeof(jsEnv));
	
	jsEnvPtr->runtime = JS_NewRuntime(8L * 1024L * 1024L);
	jsEnvPtr->context = JS_NewContext(jsEnvPtr->runtime, 8192);
	jsEnvPtr->object = JS_NewObject(jsEnvPtr->context, NULL, NULL, NULL);
	
	JS_InitStandardClasses(jsEnvPtr->context, jsEnvPtr->object);
	JS_SetErrorReporter(jsEnvPtr->context, JsLogError);
	
	Ns_TlsSet(&tls, jsEnvPtr);
	
	Ns_Log(Debug, "JsInit: %p", jsEnvPtr);
	
	Tcl_CreateObjCommand(interp, "js.eval", JsEvalObjCmd, NULL, NULL);
	
	return TCL_OK;
}

static void
JsCleanup(void *arg) 
{
	jsEnv *jsEnvPtr = arg;
	
	if (jsEnvPtr != NULL) {
		JS_DestroyContext(jsEnvPtr->context); 
		JS_DestroyRuntime(jsEnvPtr->runtime);
		JS_ShutDown();

		Ns_Log(Debug, "JsCleanup: %p", jsEnvPtr);

		ns_free(jsEnvPtr);
	}
}

static int
JsEvalObjCmd(ClientData arg, Tcl_Interp *interp, int objc, Tcl_Obj *CONST objv[])
{
	jsEnv *jsEnvPtr;
	JSContext *context;
	JSObject *object;
	Tcl_Obj *objPtr;
	JSString *str;
	jsval rval;
	char *command;
	
	if (objc != 2) {
		Tcl_WrongNumArgs(interp, 1, objv, "command");
		
		return TCL_ERROR;
	}
	
	command = Tcl_GetStringFromObj(objv[1], NULL);
	
	jsEnvPtr = Ns_TlsGet(&tls);
	
	context = jsEnvPtr->context;
	object = jsEnvPtr->object;
	
	if (!JS_EvaluateScript(context, object, command, strlen(command), "script", 1, &rval)) {
		return TCL_ERROR;
	}
	
	str = JS_ValueToString(context, rval);

	objPtr = Tcl_NewStringObj(JS_GetStringBytes(str), strlen(JS_GetStringBytes(str)));
	Tcl_SetObjResult(interp, objPtr);
	
	return TCL_OK;
}

void
JsLogError(JSContext *cx, const char *message, JSErrorReport *report)
{
	Ns_Log(Error, (char *) message);
}
