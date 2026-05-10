#!/usr/local/bin/wolframscript

Needs["AntonAntonov`Chatnik`"];

(* Using stderr for reported errors *)
AntonAntonov`Chatnik`ChatsManager`Private`Proclaimer[x_] := WriteString[OutputStream["stderr", 2], x <> "\n"];

(* Chat evaluation *)
res = ChatnikEvaluate[Rest@$ScriptCommandLine, "Clone" -> True, ProgressReporting -> False];

(* Result *)
WriteString[OutputStream["stdout", 1], ToString[res] <> "\n"];