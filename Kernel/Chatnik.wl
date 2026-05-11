(* ::Package:: *)

(* ::Section:: *)
(*Package Header*)


BeginPackage["AntonAntonov`Chatnik`"];

ScrapePromptRecords::usage = "Scrapes LLM prompts info from a given URL. (Default URL is that of Wolfram Prompt Repository.)";

ChatnikEvaluate::usage = "ChatnikEvaluate[input_String, args_Association, location_] \
evaluates a message input using chat-ID and LLM-configuration options \
using persistent chat-objects association at specified location. (\"Local\" by default.)";

ChatnikClearMessages::usage = "Clear messages of a chat object."

ChatnikPromptExpand::usage = "Expand prompts according the chatbook cells DSL.";

ChatnikPromptRecords::usage = "Give known prompt names and their short descriptions.";

ChatnikCopyScripts::usage = "Copy paclet's scripts and make them executable.";

Begin["`Private`"];

Needs["AntonAntonov`Chatnik`ChatsManager`"];
Needs["AntonAntonov`Chatnik`PromptExpander`"];
Needs["AntonAntonov`Chatnik`Scraper`"];

(***************************************************************)
(* Copy scripts                                                *)
(***************************************************************)

Clear[ChatnikCopyScripts];

ChatnikCopyScripts::naudir = "Currently automatic directory argument is supported only for the MacOSX operating systems.";
ChatnikCopyScripts::ndir = "Cannot find the directory \"`1`\".";
ChatnikCopyScripts::nargs = "The first (optional) argument is expected to be a directory path or Automatic.";

Options[ChatnikCopyScripts] = {"DropExtensions" -> True, "Aliases" -> False}; 

ChatnikCopyScripts[dir_ : Automatic] :=
 Module[{dropExtensionsQ, aliasesQ, targetDir, p},
    dropExtensionsQ = TrueQ[OptionValue[ChatnikCopyScripts, "DropExtensions"]];
    aliasesQ = TrueQ[OptionValue[ChatnikCopyScripts, "Aliases"]];
    
    (*Expand for non-MacOSX*)
    Which[
      TrueQ[dir === Automatic] && $OperatingSystem != "MacOSX",
      Message[ChatnikCopyScripts::naudir];
      Return[$Failed],

      TrueQ[dir === Automatic],
      targetDir = $HomeDirectory <> "/Applications",
     
      True, 
      targetDir = dir
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

    res = MapThread[CopyFile[#1, FileNameJoin[{targetDir, #2}], OverwriteTarget -> True]&, {fileNames, baseNames}];

    (*Make executable*)
    Map[RunProcess[{"chmod", "a+x", #}]&, res];

    res
  ];

ChatnikCopyScripts[___] := (Message[ChatnikCopyScripts::nargs]; $$Failed);

(***************************************************************)
(* Give prompts and slogans                                  *)
(***************************************************************)

lsPromptRecords = None;

Clear[ChatnikPromptRecords];

ChatnikPromptRecords[] := ChatnikPromptRecords[All];

ChatnikPromptRecords[All] :=
  Module[{p},
    If[ListQ[lsPromptRecords], 
      lsPromptRecords,
      (*ELSE*)
      p = First @ PacletFind["AntonAntonov/Chatnik"];
      lsPromptRecords = Import[FileNameJoin[{p["Location"], "Resources", "Prompt-repository-records.json"}], "RawJSON"]
    ]
  ];

ChatnikPromptRecords[name_?StringQ] :=
  Select[ChatnikPromptRecords[All], ToLowerCase[#Name] == ToLowerCase[name]&];

ChatnikPromptRecords[pat_StringExpression] :=
  Select[ChatnikPromptRecords[All], StringMatchQ[#Name, pat]&];

End[];
EndPackage[];