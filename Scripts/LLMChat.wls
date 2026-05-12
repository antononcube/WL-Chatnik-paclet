#!/usr/local/bin/wolframscript

Needs["AntonAntonov`Chatnik`"];

(* Using stderr for reported errors *)
AntonAntonov`Chatnik`ChatsManager`Private`Proclaimer[x_] := WriteString[OutputStream["stderr", 2], x <> "\n"];

(* Prepend pipeline input if given and there is no positional argument. *)
(* The no-positional-argument check might be too restrictive *)
input = Rest@$ScriptCommandLine;
stdin = $ScriptInputString;      
If[input[[1]] == "-",
    stdin = If[$OperatingSystem == "Windows",      
        $ScriptInputString, 
        (*ELSE*)
        $ScriptInputString <> Import["!cat", "String"]
    ];
    input = Rest[input]
];

If[StringQ[stdin] && StringLength[stdin] > 0 && StringMatchQ[First @ input, "-" ~~ __],
    input = Prepend[input, stdin]
];

(* Chat evaluation *)
res = ChatnikEvaluate[input, "Clone" -> True, ProgressReporting -> False];

(* Result *)
WriteString[OutputStream["stdout", 1], ToString[res] <> "\n"];