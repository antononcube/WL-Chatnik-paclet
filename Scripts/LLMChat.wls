#!/usr/local/bin/wolframscript

Needs["AntonAntonov`Chatnik`"];

(* Using stderr for reported errors *)
AntonAntonov`Chatnik`ChatsManager`Private`Proclaimer[x_] := WriteString[OutputStream["stderr", 2], x <> "\n"];

(* Prepend pipeline input if given and there is no positional argument. *)
(* The no-positional-argument might be too restrictive. *)
input = Rest@$ScriptCommandLine;
If[StringQ[$ScriptInputString] && StringLength[$ScriptInputString] > 0 && StringStartsQ[First @ input, "-"],
    If[$OperatingSystem == "Windows", 
        input = Prepend[input, $ScriptInputString], 
        (*ELSE*)
        stdin = $ScriptInputString <> Import["!cat", "String"];
        input = Prepend[input, stdin]
    ]
]

(* Chat evaluation *)
res = ChatnikEvaluate[input, "Clone" -> True, ProgressReporting -> False];

(* Result *)
WriteString[OutputStream["stdout", 1], ToString[res] <> "\n"];