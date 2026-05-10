(* ::Package:: *)

(* ::Section:: *)
(*Package Header*)


BeginPackage["AntonAntonov`Chatnik`"];

ScrapePromptRecords::usage = "Scrapes LLM prompts info from a given URL. (Default URL is that of Wolfram Prompt Repository.)";

ChatnikEvaluate::usage = "ChatnikEvaluate[input_String, args_Association, location_] \
evaluates a message input using chat-ID and LLM-configuration options \
using persistent chat-objects association at specified location. (\"Local\" by default.)";

ChatnikClearMessages::usage = "Clear messages of a chat object."

ChatnikCopyScripts::usage = "Copy paclet's scripts and make them executable.";

Begin["`Private`"];

Needs["AntonAntonov`Chatnik`Scraper`"];
Needs["AntonAntonov`Chatnik`ChatsManager`"];


Clear[ChatnikCopyScripts];

ChatnikCopyScripts::nos = "Currently Chatnik scripts are processed only for the MacOSX operating system.";
ChatnikCopyScripts::ndir = "Cannot find the directory \"`1`\".";
ChatnikCopyScripts::nargs = "The first optional argument is expected to be a directory path or Automatic.";

Options[ChatnikCopyScripts] = {"DropExtensions" -> True, "Aliases" -> False}; 

ChatnikCopyScripts[dir_ : Automatic] :=
 Module[{dropExtensionsQ, aliasesQ, targetDir, p},
    dropExtensionsQ = TrueQ[OptionValue[ChatnikCopyScripts, "DropExtensions"]];
    aliasesQ = TrueQ[OptionValue[ChatnikCopyScripts, "Aliases"]];
    
    If[$OperatingSystem != "MacOSX",
        Message[ChatnikCopyScripts::nos];
        Return[$Failed]
    ];
    
    (*Expand for non-MacOSX*)
    targetDir = If[TrueQ[dir === Automatic],
     $HomeDirectory <> "/Applications",
     dir
    ];

    If[!DirectoryQ[targetDir],
        Message[ChatnikCopyScripts::ndir, targetDir];
        Return[$Failed]
    ];

    (*Find and copy script files *)
    p = First @ PacletFind["AntonAntonov/Chatnik"];
    fileNames = FileNames["*.wls", FileNameJoin[{p["Location"], "Scripts"}]];
    baseNames = Map[Last @ FileNameSplit[#]&, fileNames];
    If[dropExtensionsQ,
        baseNames = StringReplace[#, ".wls" -> ""]& /@ baseNames
    ];

    res = MapThread[CopyFile[#1, FileNameJoin[{targetDir, #2}]]&, {fileNames, baseNames}];

    (*Make executable*)
    Map[RunProcess[{"chmod", "a+x", #}]&, res];

    res
  ];

ChatnikCopyScripts[___] := (Message[ChatnikCopyScripts::nargs]; $$Failed);

End[];
EndPackage[];